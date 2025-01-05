#include "abnativeelf.hpp"
#include "abnativefunctions.h"
#include "stdwrapper.hpp"
#include "threadpool.hpp"

#include <algorithm>
#include <cstdarg>
#include <cstring>
#include <deque>
#include <endian.h>
#include <fcntl.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <thread>

#include <elf.h>
#include <sys/wait.h>
#include <unistd.h>
#include <unordered_set>

#include <gelf.h>
#include <libelf.h>

// Workaround for older versions of glibc
#ifndef EM_LOONGARCH
#define EM_LOONGARCH 258
#endif // EM_LOONGARCH

// {'!', '<', 'a', 'r', 'c', 'h', '>', '\n'}
constexpr std::array<uint8_t, 8> ar_magic = {0x21, 0x3C, 0x61, 0x72,
                                             0x63, 0x68, 0x3E, 0x0A};

// {'!', '<', 't', 'h', 'i', 'n', '>', '\n'}
constexpr std::array<uint8_t, 8> ar_thin_magic = {0x21, 0x3C, 0x74, 0x68,
                                                  0x69, 0x6E, 0x3E, 0x0A};

// {'B', 'C', '\xC0', '\xDE'}
constexpr std::array<uint8_t, 4> llvm_bc_magic = {0x42, 0x43, 0xC0, 0xDE};

// Loongson2F (MIPS-III) (= 0x20000000)
constexpr uint32_t elf_flags_loongson2f = EF_MIPS_ARCH_3;

// Loongson3 (MIPS) (= 0x80a20000)
constexpr uint32_t elf_flags_loongson3 = EF_MIPS_ARCH_64R2 | EF_MIPS_MACH_GS464;

// MIPS64R6EL (= 0xa0000400)
constexpr uint32_t elf_flags_mips64r6el = EF_MIPS_ARCH_64R6 | EF_MIPS_NAN2008;

constexpr uint32_t elf_min_size = sizeof(Elf32_Ehdr);

enum class Endianness : bool {
  Little = true,
  Big = false,
};

static const GElf_Shdr *
find_elf_section_header(const std::vector<GElf_Shdr> &section_headers,
                        Elf *elf_file, size_t shstrndx, const char *name,
                        const uint32_t type) {
  for (const auto &shdr : section_headers) {
    const Elf64_Word sh_type = shdr.sh_type;
    if (sh_type != type)
      continue;
    const Elf64_Word name_idx = shdr.sh_name;
    const char *section_name = elf_strptr(elf_file, shstrndx, name_idx);
    if (!section_name || memcmp(section_name, name, strlen(name)) != 0)
      continue;
    return &shdr;
  }
  return nullptr;
}

static size_t get_elf_dynstrtab(Elf *elf_file,
                                const std::vector<GElf_Shdr> &section_headers,
                                size_t shstrndx) {
  constexpr const char *sh_dynstr = ".dynstr";
  const auto shdr = find_elf_section_header(section_headers, elf_file, shstrndx,
                                            sh_dynstr, SHT_STRTAB);
  if (shdr != nullptr) {
    Elf_Scn *scn = gelf_offscn(elf_file, shdr->sh_offset);
    return elf_ndxscn(scn);
  } else {
    return 0;
  }
}

static std::vector<const char *>
get_elf_needed(Elf *elf_file, const std::vector<GElf_Shdr> &section_headers,
               GElf_Off dynstrtab) {
  std::vector<const char *> needed{};
  if (!dynstrtab)
    return needed;
  for (const auto &shdr : section_headers) {
    const uint32_t type = shdr.sh_type;
    if (type != SHT_DYNAMIC)
      continue;

    Elf_Scn *section = gelf_offscn(elf_file, shdr.sh_offset);
    Elf_Data *dyn_data = elf_getdata(section, nullptr);
    GElf_Dyn dyn{};
    int entry = 0;
    while ((gelf_getdyn(dyn_data, entry, &dyn))) {
      if (dyn.d_tag == DT_NEEDED) {
        const uint32_t name_idx = dyn.d_un.d_val;
        const char *section_name = elf_strptr(elf_file, dynstrtab, name_idx);
        needed.push_back(section_name);
      }
      entry++;
    }
  }
  return needed;
}

static std::string
get_elf_build_id(Elf *elf_file, const std::vector<GElf_Shdr> &section_headers,
                 GElf_Off shstrndx) {
  constexpr const char table[] = {'0', '1', '2', '3', '4', '5', '6', '7',
                                  '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
  std::string build_id{};
  constexpr const char *sh_gnu_build_id = ".note.gnu.build-id";
  // constexpr const char *sh_go_build_id = ".note.go.buildid";
  const auto section_header = find_elf_section_header(
      section_headers, elf_file, shstrndx, sh_gnu_build_id, SHT_NOTE);
  if (section_header == nullptr)
    return build_id;
  GElf_Nhdr result{};
  Elf_Scn *section = gelf_offscn(elf_file, section_header->sh_offset);
  Elf_Data *note_data = elf_getdata(section, nullptr);
  if (!note_data)
    return build_id;
  size_t name_offset = 0;
  size_t desc_offset = 0;
  if (!gelf_getnote(note_data, 0, &result, &name_offset, &desc_offset))
    return build_id;
  const unsigned char *value = (unsigned char *)note_data->d_buf + desc_offset;
  for (size_t i = 0; i < result.n_descsz; i++) {
    const unsigned char hi = table[(value[i] & 0xF0) >> 4];
    const unsigned char lo = table[(value[i] & 0x0F) >> 0];
    build_id += hi;
    build_id += lo;
  }

  return build_id;
}

static const uint64_t decode_uleb128(const unsigned char *start,
                                     const size_t pos_max, size_t &pos) {
  uint64_t ret = 0;
  uint8_t shift = 0;
  while (pos < pos_max) {
    ret |= (start[pos] & 0x7F) << shift;
    pos += 1;
    if ((start[pos] & 0x80) == 0)
      break;
    shift += 7;
  }
  return le64toh(ret);
}

static const bool is_null_terminated_string(const uint64_t tag) {
  // Tags with null-terminated string as values: 4: CPU_raw_name, 5: CPU_name,
  // 67: conformance
  constexpr const uint64_t tag_string[] = {4, 5, 67};
  for (const auto i : tag_string) {
    if (i == tag) {
      return true;
    }
  }
  return false;
}

// Ref: ELF for the Arm Architecture - Section 5.3.6
// Ref: readelf.c from binutils
static AOSCArch get_elf_arm_arch(Elf *elf_file, Endianness endianness,
                                 const std::vector<GElf_Shdr> &section_headers,
                                 size_t shstrndx) {
  constexpr const char *sh_abi_tag = ".ARM.attributes";
  constexpr const char *vendor_name = "aeabi";
  bool hard_float = false;
  const auto vendor_name_len = strlen(vendor_name);
  auto ret = AOSCArch::NONE;
  const auto section_header = find_elf_section_header(
      section_headers, elf_file, shstrndx, sh_abi_tag, SHT_ARM_ATTRIBUTES);
  if (section_header == nullptr)
    return ret;
  Elf_Scn *section = gelf_offscn(elf_file, section_header->sh_offset);
  Elf_Data *dyn_data = elf_getdata(section, nullptr);
  unsigned char *start = reinterpret_cast<unsigned char *>(dyn_data->d_buf);
  const auto size = section_header->sh_size;
  // Version identifier 'A'
  if (*start != 'A')
    return ret;
  size_t pos = 1;

  // Parse sections
  while (pos < size) {
    uint32_t section_length = *reinterpret_cast<const uint32_t *>(start + pos);
    if (endianness == Endianness::Little) {
      section_length = le32toh(section_length);
    } else {
      section_length = be32toh(section_length);
    }
    const auto section_end = pos + section_length;
    pos += 4;
    // only check section with pseudo-vendor 'aeabi'
    if (memcmp(start + pos, vendor_name, vendor_name_len) != 0) {
      pos = section_end;
      continue;
    }
    pos += vendor_name_len + 1;

    // 0x01 marks for Tag_File, ignore other subsections
    if (start[pos] != 0x01) {
      pos = section_end;
      continue;
    }

    // Read attributes length
    uint32_t attributes_length =
        *reinterpret_cast<const uint32_t *>(start + pos + 1);
    if (pos + attributes_length > section_end)
      return AOSCArch::NONE;
    const size_t attributes_end = pos + attributes_length;
    pos += 5;

    // Parse attributes
    while (pos < attributes_end) {
      const auto tag = decode_uleb128(start, attributes_end, pos);
      if (is_null_terminated_string(tag)) {
        const size_t val_len =
            strlen(reinterpret_cast<const char *>(start) + pos);
        pos += val_len + 1;
        if (pos > attributes_end) {
          return AOSCArch::NONE;
        }
        continue;
      }
      const auto value = decode_uleb128(start, attributes_end, pos);
      switch (tag) {
      // CPU_arch
      case 6:
        switch (value) {
        // v4
        case 1:
          ret = AOSCArch::ARMV4;
          break;
        // v6
        case 6:
          ret = AOSCArch::ARMV6HF;
          break;
        // v7
        case 10:
          ret = AOSCArch::ARMV7HF;
          break;
        default:
          return AOSCArch::NONE;
        }
        break;
      // ABI_VFP_args
      case 28:
        // VFP registers
        if (value == 1)
          hard_float = true;
        break;
      }
    }
  }
  // Detect unsupported combinations
  if ((ret == AOSCArch::ARMV4) && hard_float) {
    return AOSCArch::NONE;
  } else if (((ret == AOSCArch::ARMV6HF) || (ret == AOSCArch::ARMV7HF)) &&
             (!hard_float)) {
    return AOSCArch::NONE;
  }
  return ret;
}

static std::string get_elf_soname(Elf *elf_file,
                                  const std::vector<GElf_Shdr> &section_headers,
                                  GElf_Off dynstrtab) {
  for (const GElf_Shdr &shdr : section_headers) {
    const uint32_t type = shdr.sh_type;
    // soname section is a dynamic section
    if (type != SHT_DYNAMIC) {
      continue;
    }
    Elf_Scn *section = gelf_offscn(elf_file, shdr.sh_offset);
    Elf_Data *dyn_data = elf_getdata(section, nullptr);
    GElf_Dyn dyn{};
    int entry = 0;
    while ((gelf_getdyn(dyn_data, entry, &dyn))) {
      if (dyn.d_tag == DT_SONAME) {
        const uint32_t name_idx = dyn.d_un.d_val;
        const char *section_name = elf_strptr(elf_file, dynstrtab, name_idx);
        return std::string{section_name};
      }
      entry++;
    }
  }
  return std::string{};
}

static bool maybe_kernel_object(const std::vector<GElf_Shdr> &section_headers,
                                Elf *elf_file, size_t shstrndx) {
  constexpr const char *sh_note = ".note.Linux";
  return find_elf_section_header(section_headers, elf_file, shstrndx, sh_note,
                                 SHT_NOTE) != nullptr;
}

static inline bool
is_debug_info_present(const std::vector<GElf_Shdr> &section_headers,
                      Elf *elf_file, size_t shstrndx) {
  constexpr const char *sh_debug_info = ".debug_";
  const size_t sh_debug_info_sz = strlen(sh_debug_info);
  for (const auto &shdr : section_headers) {
    const Elf64_Word name_idx = shdr.sh_name;
    const char *section_name = elf_strptr(elf_file, shstrndx, name_idx);
    if (strlen(section_name) >= 8 &&
        memcmp(section_name, sh_debug_info, sh_debug_info_sz) != 0)
      continue;
    return true;
  }
  return false;
}

const AOSCArch detect_architecture(Elf *elf_file, GElf_Ehdr &elf_ehdr,
                                   const Endianness endian,
                                   std::vector<GElf_Shdr> &section_headers,
                                   const Elf64_Off dynstrtab,
                                   const bool is_64bit) {
  switch (elf_ehdr.e_machine) {
  case EM_X86_64:
    return AOSCArch::AMD64;
  case EM_AARCH64:
    return AOSCArch::ARM64;
  case EM_ARM:
    // Checks .ARM.attributes
    return get_elf_arm_arch(elf_file, endian, section_headers, dynstrtab);
  // Assumes EM_386 binaries are always i486-compatible
  case EM_386:
    return AOSCArch::I486;
  case EM_LOONGARCH:
    if (is_64bit) {
      return AOSCArch::LOONGARCH64;
    } else {
      return AOSCArch::NONE;
    }
  case EM_MIPS:
    // MIPS{32,64}BE aren't supported
    if (endian == Endianness::Big) {
      return AOSCArch::NONE;
    }
    // e_flags-based detection
    if (elf_ehdr.e_flags & elf_flags_loongson2f) {
      return AOSCArch::LOONGSON2F;
    } else if (elf_ehdr.e_flags & elf_flags_loongson3) {
      return AOSCArch::LOONGSON3;
    } else if (elf_ehdr.e_flags & elf_flags_mips64r6el) {
      return AOSCArch::MIPS64R6EL;
    } else {
      return AOSCArch::NONE;
    }
  case EM_PPC:
    if (endian == Endianness::Big) {
      return AOSCArch::POWERPC;
    } else {
      return AOSCArch::NONE;
    }
  case EM_PPC64:
    if (endian == Endianness::Big) {
      return AOSCArch::PPC64;
    } else {
      return AOSCArch::PPC64EL;
    }
  case EM_RISCV:
    // TODO: Check RISC-V attributes for better accuracy
    if (is_64bit) {
      return AOSCArch::RISCV64;
    } else {
      return AOSCArch::NONE;
    }
  case EM_SPARCV9:
    return AOSCArch::SPARC64;
  default:
    return AOSCArch::NONE;
  }
}

static ELFParseResult identify_binary_data(const char *data,
                                           const size_t size) {
  ELFParseResult result{};
  if (size >= 8 && memcmp(data, ar_magic.data(), ar_magic.size()) == 0) {
    result.bin_type = BinaryType::Static;
    return result;
  } else if (size >= 8 &&
             memcmp(data, ar_thin_magic.data(), ar_thin_magic.size()) == 0) {
    result.bin_type = BinaryType::Static;
    return result;
  } else if (size >= 4 &&
             memcmp(data, llvm_bc_magic.data(), llvm_bc_magic.size()) == 0) {
    result.bin_type = BinaryType::LLVM_IR;
    return result;
  }

  // identify ELF files
  if (size < elf_min_size) {
    result.bin_type = BinaryType::Invalid;
    return result;
  }
  if (memcmp(data, ELFMAG, SELFMAG) != 0) {
    result.bin_type = BinaryType::Invalid;
    return result;
  }

  Elf *elf_file = elf_memory(const_cast<char *>(data), size);
  GElf_Ehdr elf_ehdr{};
  gelf_getehdr(elf_file, &elf_ehdr);
  const char *shstr_start = nullptr;
  const uint8_t endianness = elf_ehdr.e_ident[EI_DATA];
  if (endianness != ELFDATA2LSB && endianness != ELFDATA2MSB) {
    result.bin_type = BinaryType::Invalid;
    return result;
  }
  const Endianness endian =
      (endianness == ELFDATA2LSB ? Endianness::Little : Endianness::Big);

  const uint16_t e_type = elf_ehdr.e_type;

  BinaryType type = BinaryType::Invalid;

  switch (e_type) {
  case ET_EXEC:
    type = BinaryType::Executable;
    break;
  case ET_DYN:
    type = BinaryType::Dynamic;
    break;
  case ET_REL:
    type = BinaryType::Relocatable;
    break;
  default:
    type = BinaryType::Invalid;
    break;
  }

  result.bin_type = type;
  if (elf_ehdr.e_shstrndx == SHN_UNDEF)
    return result;
  Elf_Scn *scn = nullptr;
  std::vector<GElf_Shdr> section_headers{};
  while ((scn = elf_nextscn(elf_file, scn))) {
    GElf_Shdr shdr{};
    gelf_getshdr(scn, &shdr);
    section_headers.emplace_back(shdr);
  }

  // extract build id and library depends
  size_t shstrndx = 0;
  elf_getshdrstrndx(elf_file, &shstrndx);
  const auto build_id = get_elf_build_id(elf_file, section_headers, shstrndx);
  const auto dynstrtab = get_elf_dynstrtab(elf_file, section_headers, shstrndx);
  const auto soname = get_elf_soname(elf_file, section_headers, dynstrtab);
  if (type == BinaryType::Relocatable &&
      maybe_kernel_object(section_headers, elf_file, shstrndx)) {
    result.bin_type = BinaryType::KernelObject;
  } else {
    auto needed = get_elf_needed(elf_file, section_headers, dynstrtab);
    result.needed_libs = std::move(needed);
  }
  result.build_id = std::move(build_id);
  result.soname = std::move(soname);
  result.has_debug_info =
      is_debug_info_present(section_headers, elf_file, shstrndx);
  const bool is_64bit = gelf_getclass(elf_file) == ELFCLASS64;

  // detect architecture
  result.arch = detect_architecture(elf_file, elf_ehdr, endian, section_headers,
                                    dynstrtab, is_64bit);

  elf_end(elf_file);
  return result;
}

inline static fs::path get_filename_from_build_id(const std::string &build_id,
                                                  const char *dst_path) {
  const std::string &build_id_str{build_id};
  const std::string prefix = build_id_str.substr(0, 2);
  const std::string suffix = build_id_str.substr(2);
  fs::path final_path{dst_path};
  final_path /= ("usr/lib/debug/.build-id/" + prefix);
  final_path /= (suffix + ".debug");

  return final_path;
}

class MappedFile {
public:
  MappedFile(int fd, size_t size) : m_fd{fd}, m_size{size} {
    if (m_fd == -1) {
      m_addr = MAP_FAILED;
      return;
    }
    m_addr = mmap(nullptr, m_size, PROT_READ, MAP_PRIVATE, m_fd, 0);
  }
  ~MappedFile() {
    if (m_addr != MAP_FAILED)
      munmap(m_addr, m_size);
    if (m_fd >= 0)
      close(m_fd);
  }
  inline void *addr() const { return m_addr; }
  inline size_t size() const { return m_size; }

private:
  int m_fd;
  void *m_addr;
  size_t m_size;
};

static inline int forked_execvp(const char *path, char *const argv[]) {
  const pid_t pid = fork();
  if (pid == 0) {
    execvp(path, argv);
  }
  // wait for the child process to exit
  int status = 0;
  waitpid(pid, &status, 0);
  return status;
}

static const std::unordered_set<std::string>
aosc_arch_to_debian_arch_suffix(const AOSCArch arch) {
  switch (arch) {
  case AOSCArch::AMD64:
    return {"amd64"};
  case AOSCArch::ARM64:
    return {"arm64"};
  case AOSCArch::ARMV4:
    return {"armel"};
  case AOSCArch::ARMV6HF:
  case AOSCArch::ARMV7HF:
    return {"armhf"};
  case AOSCArch::I486:
    return {"i386"};
  case AOSCArch::LOONGARCH64:
    return {"loong64", "loongarch64"};
  case AOSCArch::LOONGSON2F:
  case AOSCArch::LOONGSON3:
    return {"mips64el"};
  case AOSCArch::MIPS64R6EL:
    return {"mips64r6el"};
  case AOSCArch::POWERPC:
    return {"powerpc"};
  case AOSCArch::PPC64:
    return {"ppc64"};
  case AOSCArch::PPC64EL:
    return {"ppc64el"};
  case AOSCArch::RISCV64:
    return {"riscv64"};
  case AOSCArch::SPARC64:
    return {"sparc64"};
  default:
    return {};
  }
}

class FileLockGuard {
public:
  FileLockGuard(int fd) : m_fd{fd} { flock(m_fd, LOCK_EX); }

  ~FileLockGuard() { flock(m_fd, LOCK_UN); }

private:
  int m_fd;
};

int elf_copy_debug_symbols(const char *src_path, const char *dst_path,
                           int flags, GuardedSet<std::string> &symbols,
                           GuardedSet<std::string> &sonames) {
  int fd = open(src_path, O_RDONLY, 0);
  if (fd < 0) {
    perror("open");
    return -1;
  }
  FileLockGuard lock{fd};
  struct stat st {};
  if (fstat(fd, &st) < 0) {
    perror("fstat");
    return -1;
  }
  const size_t size = st.st_size;
  const MappedFile file{fd, size};
  std::vector<const char *> args{"", "--remove-section=.comment",
                                 "--remove-section=.note"};
  std::vector<const char *> extra_args{}; // for binutils
  args.reserve(8);
  extra_args.reserve(1);
  const char *data = static_cast<const char *>(file.addr());
  const ELFParseResult result = identify_binary_data(data, size);

  constexpr const char *base_path = "/usr/lib/";
  constexpr const size_t base_len = sizeof(base_path);

  const std::string filename(basename(src_path));
  const size_t filename_len = filename.size();
  const size_t src_len = strlen(src_path);
  bool in_usr_lib = false;
  if (src_len >= (base_len + filename_len)) {
    const int src_offset = src_len - base_len - filename_len - 1;
    in_usr_lib = (memcmp(src_path + src_offset, base_path, base_len) == 0);
  }
  if ((flags & AB_ELF_FIND_SONAMES) && in_usr_lib && (!result.soname.empty())) {
    const auto suffixes = aosc_arch_to_debian_arch_suffix(result.arch);
    if (suffixes.empty()) {
      sonames.emplace(result.soname);
    } else {
      for (const auto &suffix : suffixes) {
        sonames.emplace(fmt::format("{0}:{1}", result.soname, suffix));
      }
    }
  }

  if (flags & AB_ELF_FIND_SO_DEPS) {
    symbols.insert(result.needed_libs.begin(), result.needed_libs.end());
  }

  if (flags & AB_ELF_CHECK_ONLY)
    return 0;

  if (!result.has_debug_info) {
    // no debug info, strip only
    flags |= AB_ELF_STRIP_ONLY;
  }

  switch (result.bin_type) {
  case BinaryType::Invalid:
    // skip this file
    return 0;
  case BinaryType::LLVM_IR:
    // skip and also notify the caller
    return 1;
  case BinaryType::Static:
    // skip static library
    flags |= AB_ELF_STRIP_ONLY;
    break;
  case BinaryType::Executable:
    // strip all symbols
    args.emplace_back("-s");
    break;
  case BinaryType::Relocatable:
    // disable debug symbol saving for relocatables
    // also uses GNU binutils strip for compatibility
    flags |= AB_ELF_STRIP_ONLY;
    flags &= ~AB_ELF_USE_EU_STRIP;
    args.emplace_back("--strip-debug");
    extra_args.emplace_back("--enable-deterministic-archives");
    break;
  case BinaryType::Dynamic:
  case BinaryType::KernelObject:
    extra_args.emplace_back("--strip-unneeded");
    break;
  }

  get_logger()->info(
      fmt::format("Saving and stripping debug symbols from {0}", src_path));

  if (!result.has_debug_info) {
    get_logger()->warning(
        fmt::format("No debug symbols found in {0}", src_path));
    return -3;
  }

  if (result.build_id.empty() && !(flags & AB_ELF_SAVE_WITH_PATH)) {
    // For binaries without build-id, save with path
    flags |= AB_ELF_SAVE_WITH_PATH;
    get_logger()->warning(fmt::format(
        "No build id found in {0}. Saving with relative path", src_path));
  }

  fs::path final_path;
  if (flags & AB_ELF_SAVE_WITH_PATH) {
    final_path = fs::path{dst_path} / fs::path{src_path}.filename();
    get_logger()->debug(fmt::format("Saving to {0}", final_path.string()));
  } else {
    final_path = get_filename_from_build_id(result.build_id, dst_path);
  }

  if (!(flags & AB_ELF_STRIP_ONLY)) {
    // No need to create directories if we aren't going to save symbol files
    const fs::path final_prefix = final_path.parent_path();
    fs::create_directories(final_prefix);
  }

  if (flags & AB_ELF_USE_EU_STRIP) {
    args[0] = "eu-strip";
    if (!(flags & AB_ELF_STRIP_ONLY)) {
      args.emplace_back("--reloc-debug-sections");
      args.emplace_back("-f");
      args.emplace_back(final_path.c_str());
    }
    args.emplace_back(src_path);
    args.emplace_back(nullptr);
    return forked_execvp("eu-strip", const_cast<char *const *>(args.data()));
  }
  if (!(flags & AB_ELF_STRIP_ONLY)) {
    const auto path = final_path.string();
    const char *args[] = {"objcopy", "--only-keep-debug", src_path,
                          path.c_str(), nullptr};
    int ret = forked_execvp("objcopy", const_cast<char *const *>(args));
    if (ret != 0) {
      return ret;
    }
  }
  args[0] = "strip";
  std::copy(extra_args.begin(), extra_args.end(), std::back_inserter(args));
  args.emplace_back(src_path);
  args.emplace_back(nullptr);
  return forked_execvp("strip", const_cast<char *const *>(args.data()));
}

int elf_copy_to_symdir(const char *src_path, const char *dst_path,
                       const char *build_id) {
  const fs::path final_path = get_filename_from_build_id(build_id, dst_path);
  const fs::path final_prefix = final_path.parent_path();
  fs::create_directories(final_prefix);
  if (fs::copy_file(src_path, final_path,
                    fs::copy_options::overwrite_existing)) {
    return 127;
  }
  const int ret = chmod(final_path.c_str(), 0644);
  if (ret != 0) {
    return ret;
  }
  return chown(final_path.c_str(), 0, 0);
}

class ELFWorkerPool : public ThreadPool<std::string, int> {
public:
  ELFWorkerPool(std::string symdir, int flags)
      : ThreadPool<std::string, int>([&, flags](const std::string &src_path) {
          return elf_copy_debug_symbols(src_path.c_str(), m_symdir.c_str(),
                                        flags, m_sodeps, m_sonames);
        }),
        m_symdir(std::move(symdir)), m_sodeps(), m_sonames() {}

  const std::unordered_set<std::string> get_sodeps() const {
    return m_sodeps.get_set();
  }

  const std::unordered_set<std::string> get_sonames() const {
    return m_sonames.get_set();
  }

private:
  const std::string m_symdir;
  GuardedSet<std::string> m_sodeps;
  GuardedSet<std::string> m_sonames;
};

int elf_copy_debug_symbols_parallel(const std::vector<std::string> &directories,
                                    const char *dst_path,
                                    std::unordered_set<std::string> &so_deps,
                                    std::unordered_set<std::string> &sonames,
                                    int flags) {
  ELFWorkerPool pool{dst_path, flags};
  for (const auto &directory : directories) {
    for (const auto &entry : fs::recursive_directory_iterator(directory)) {
      if (entry.is_regular_file() && (!entry.is_symlink())) {
        // queue the files
        pool.enqueue(entry.path().string());
      }
    }
  }

  pool.wait_for_completion();

  if (flags & AB_ELF_FIND_SO_DEPS) {
    const auto pool_results = pool.get_sodeps();
    so_deps.insert(pool_results.begin(), pool_results.end());
  }

  if (flags & AB_ELF_FIND_SONAMES) {
    const auto sonames_results = pool.get_sonames();
    sonames.insert(sonames_results.begin(), sonames_results.end());
  }

  if (pool.has_error())
    return 1;

  return 0;
}
