#include "abnativeelf.hpp"
#include "abnativefunctions.h"
#include "stdwrapper.hpp"
#include "threadpool.hpp"

#include <cstdarg>
#include <cstring>
#include <deque>
#include <endian.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <thread>

#include <elf.h>
#include <sys/wait.h>
#include <unistd.h>
#include <unordered_set>

// {'!', '<', 'a', 'r', 'c', 'h', '>', '\n'}
constexpr std::array<uint8_t, 8> ar_magic = {0x21, 0x3C, 0x61, 0x72,
                                             0x63, 0x68, 0x3E, 0x0A};

// {'!', '<', 't', 'h', 'i', 'n', '>', '\n'}
constexpr std::array<uint8_t, 8> ar_thin_magic = {0x21, 0x3C, 0x74, 0x68,
                                                  0x69, 0x6E, 0x3E, 0x0A};

// {'B', 'C', '\xC0', '\xDE'}
constexpr std::array<uint8_t, 4> llvm_bc_magic = {0x42, 0x43, 0xC0, 0xDE};

constexpr uint32_t elf_min_size = sizeof(Elf32_Ehdr);

enum class Endianness : bool {
  Little = true,
  Big = false,
};

template <typename ElfXX_Off>
static inline ElfXX_Off get_offset(const ElfXX_Off offset,
                                   const Endianness endianness) {
  constexpr size_t size = sizeof(ElfXX_Off);
  static_assert(size == 2 || size == 4 || size == 8, "Invalid size");
  if (endianness == Endianness::Little) {
    switch (size) {
    case 2:
      return le16toh(offset);
    case 4:
      return le32toh(offset);
    case 8:
      return le64toh(offset);
    }
  } else {
    switch (size) {
    case 2:
      return be16toh(offset);
    case 4:
      return be32toh(offset);
    case 8:
      return be64toh(offset);
    }
  }
  // UNREACHABLE
  __builtin_unreachable();
}

#define ELFXX_ADD_GETTER_INNER(name, getter)                                   \
  using ElfXX_##name##_t = decltype(BaseWrapper::elf64->getter);               \
  inline ElfXX_##name##_t name() const {                                       \
    if IFCONSTEXPR (sizeof(ElfXX_##name##_t) > 1)                              \
      return m_is64bit ? get_offset(m_data.elf64->getter, m_endianness)        \
                       : get_offset(m_data.elf32->getter, m_endianness);       \
    else                                                                       \
      return m_is64bit ? m_data.elf64->getter : m_data.elf32->getter;          \
  }

#define ELFXX_ADD_GETTER(name) ELFXX_ADD_GETTER_INNER(name, name)

template <typename Elf32Type, typename Elf64Type> class ElfXX_Header_Base {
public:
  ElfXX_Header_Base(Elf32Type *elf32, Endianness endianness)
      : m_is64bit(false), m_data({.elf32 = elf32}), m_endianness(endianness) {}
  ElfXX_Header_Base(Elf64Type *elf64, Endianness endianness)
      : m_is64bit(true), m_data({.elf64 = elf64}), m_endianness(endianness) {}
  ElfXX_Header_Base()
      : m_is64bit(false), m_data({}), m_endianness(Endianness::Little) {}
  ElfXX_Header_Base(const char *data, bool is64bit, Endianness endianness)
      : m_is64bit(is64bit), m_endianness(endianness) {
    if (m_is64bit) {
      m_data.elf64 = reinterpret_cast<Elf64Type *>(data);
    } else {
      m_data.elf32 = reinterpret_cast<Elf32Type *>(data);
    }
  }
  inline bool is_64bit() const { return m_is64bit; }
  inline Endianness endianness() const { return m_endianness; }
  inline size_t size() const {
    return m_is64bit ? sizeof(Elf64Type) : sizeof(Elf32Type);
  }

protected:
  union BaseWrapper {
    const Elf32Type *elf32;
    const Elf64Type *elf64;
  };

  bool m_is64bit;
  BaseWrapper m_data;
  Endianness m_endianness;
};

class ElfXX_Ehdr
    : public ElfXX_Header_Base<const Elf32_Ehdr, const Elf64_Ehdr> {
public:
  ElfXX_Ehdr(const Elf32_Ehdr *elf32, Endianness endianness)
      : ElfXX_Header_Base(elf32, endianness) {}
  ElfXX_Ehdr(const Elf64_Ehdr *elf64, Endianness endianness)
      : ElfXX_Header_Base(elf64, endianness) {}
  ElfXX_Ehdr() : ElfXX_Header_Base() {}

  // Add getters using macros
  ELFXX_ADD_GETTER(e_type);
  ELFXX_ADD_GETTER(e_entry);
  ELFXX_ADD_GETTER(e_shnum);
  ELFXX_ADD_GETTER(e_shstrndx);
  ELFXX_ADD_GETTER(e_shoff);
};

class ElfXX_Shdr
    : public ElfXX_Header_Base<const Elf32_Shdr, const Elf64_Shdr> {
public:
  ElfXX_Shdr(const Elf32_Shdr *elf32, Endianness endianness)
      : ElfXX_Header_Base(elf32, endianness) {}
  ElfXX_Shdr(const Elf64_Shdr *elf64, Endianness endianness)
      : ElfXX_Header_Base(elf64, endianness) {}
  ElfXX_Shdr() : ElfXX_Header_Base() {}

  // Add getters using macros
  ELFXX_ADD_GETTER(sh_name);
  ELFXX_ADD_GETTER(sh_type);
  ELFXX_ADD_GETTER(sh_offset);
  ELFXX_ADD_GETTER(sh_size);
};

class ElfXX_Nhdr
    : public ElfXX_Header_Base<const Elf32_Nhdr, const Elf64_Nhdr> {
public:
  ElfXX_Nhdr(const Elf32_Nhdr *elf32, Endianness endianness)
      : ElfXX_Header_Base(elf32, endianness) {}
  ElfXX_Nhdr(const Elf64_Nhdr *elf64, Endianness endianness)
      : ElfXX_Header_Base(elf64, endianness) {}
  ElfXX_Nhdr() : ElfXX_Header_Base() {}
  ElfXX_Nhdr(const char *data, bool is64bit, Endianness endianness)
      : ElfXX_Header_Base(data, is64bit, endianness) {}

  // Add getters using macros
  ELFXX_ADD_GETTER(n_type);
  ELFXX_ADD_GETTER(n_namesz);
  ELFXX_ADD_GETTER(n_descsz);
};

class ElfXX_Dyn : public ElfXX_Header_Base<const Elf32_Dyn, const Elf64_Dyn> {
public:
  ElfXX_Dyn(const Elf32_Dyn *elf32, Endianness endianness)
      : ElfXX_Header_Base(elf32, endianness) {}
  ElfXX_Dyn(const Elf64_Dyn *elf64, Endianness endianness)
      : ElfXX_Header_Base(elf64, endianness) {}
  ElfXX_Dyn() : ElfXX_Header_Base() {}
  ElfXX_Dyn(const char *data, bool is64bit, Endianness endianness)
      : ElfXX_Header_Base(data, is64bit, endianness) {}

  // Add getters using macros
  ELFXX_ADD_GETTER(d_tag);
  ELFXX_ADD_GETTER_INNER(d_val, d_un.d_val);
  ELFXX_ADD_GETTER_INNER(d_ptr, d_un.d_ptr);
};

#undef ELFXX_ADD_GETTER
#undef ELFXX_ADD_GETTER_INNER

static inline const ElfXX_Shdr get_section_header(const ElfXX_Ehdr &elf_header,
                                                  const uint32_t index,
                                                  const char *file_start) {
  const char *section_header_start =
      reinterpret_cast<const char *>(file_start) + elf_header.e_shoff();
  if (elf_header.is_64bit()) {
    const auto *shdr =
        &reinterpret_cast<const Elf64_Shdr *>(section_header_start)[index];
    return {shdr, elf_header.endianness()};
  } else {
    const auto *shdr =
        &reinterpret_cast<const Elf32_Shdr *>(section_header_start)[index];
    return {shdr, elf_header.endianness()};
  }
}

static std::vector<const char *>
get_elf_needed(const char *file_start,
               const std::vector<ElfXX_Shdr> &section_headers,
               const char *shstrtab) {
  // constexpr const char *sh_dyn = ".dynamic";
  constexpr const char *sh_dynstr = ".dynstr";
  const char *dynstrtab = nullptr;
  std::vector<const char *> needed{};

  for (const auto &shdr : section_headers) {
    const uint32_t type = shdr.sh_type();
    if (type != SHT_STRTAB)
      continue;
    const uint32_t name_idx = shdr.sh_name();
    const char *section_name =
        reinterpret_cast<const char *>(shstrtab + name_idx);
    if (memcmp(section_name, sh_dynstr, strlen(sh_dynstr)) != 0) {
      continue;
    }
    dynstrtab = reinterpret_cast<const char *>(file_start) + shdr.sh_offset();
    break;
  }

  if (dynstrtab == nullptr)
    return {};
  for (const auto &shdr : section_headers) {
    const uint32_t type = shdr.sh_type();
    if (type != SHT_DYNAMIC)
      continue;

    const char *dyn_start =
        reinterpret_cast<const char *>(file_start) + shdr.sh_offset();
    const char *dyn_end = dyn_start + shdr.sh_size();
    while (dyn_start < dyn_end) {
      const auto dyn = ElfXX_Dyn{dyn_start, shdr.is_64bit(), shdr.endianness()};
      if (dyn.d_tag() == DT_NEEDED) {
        const uint32_t name_idx = dyn.d_val();
        const char *section_name =
            reinterpret_cast<const char *>(dynstrtab + name_idx);
        needed.push_back(section_name);
      }
      dyn_start += dyn.size();
    }
  }
  return needed;
}

static std::string
get_elf_build_id(const char *file_start,
                 const std::vector<ElfXX_Shdr> &section_headers,
                 const char *shstrtab) {
  constexpr const char table[] = {'0', '1', '2', '3', '4', '5', '6', '7',
                                  '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'};
  std::string build_id{};
  constexpr const char *sh_gnu_build_id = ".note.gnu.build-id";
  constexpr const char *sh_go_build_id = ".note.go.buildid";
  for (const ElfXX_Shdr &section_header : section_headers) {
    const uint32_t type = section_header.sh_type();
    // build id section is a note section
    if (type != SHT_NOTE) {
      continue;
    }
    const uint32_t name_idx = section_header.sh_name();
    const char *section_name =
        reinterpret_cast<const char *>(shstrtab + name_idx);
    if (memcmp(section_name, sh_gnu_build_id, strlen(sh_gnu_build_id)) != 0) {
      continue;
    }

    const char *note_start = file_start + section_header.sh_offset();
    ElfXX_Nhdr note_header = {note_start, section_header.is_64bit(),
                              section_header.endianness()};
    size_t header_size = note_header.size();
    const unsigned char *value =
        reinterpret_cast<const unsigned char *>(note_start) + header_size +
        note_header.n_namesz();
    for (size_t i = 0; i < note_header.n_descsz(); i++) {
      const unsigned char hi = table[(value[i] & 0xF0) >> 4];
      const unsigned char lo = table[(value[i] & 0x0F) >> 0];
      build_id += hi;
      build_id += lo;
    }
  }

  return build_id;
}

static bool maybe_kernel_object(const std::vector<ElfXX_Shdr> &section_headers,
                                const char *shstrtab) {
  constexpr const char *sh_note = ".note.Linux";
  for (const ElfXX_Shdr &section_header : section_headers) {
    const uint32_t type = section_header.sh_type();
    if (type != SHT_NOTE) {
      continue;
    }
    const uint32_t name_idx = section_header.sh_name();
    const char *section_name =
        reinterpret_cast<const char *>(shstrtab + name_idx);
    if (memcmp(section_name, sh_note, strlen(sh_note)) == 0) {
      return true;
    }
  }
  return false;
}

static inline bool
is_debug_info_present(const std::vector<ElfXX_Shdr> &section_headers,
                      const char *shstrtab) {
  constexpr const char *sh_debug_info = ".debug_info";
  for (const ElfXX_Shdr &section_header : section_headers) {
    const uint32_t type = section_header.sh_type();
    if (type != SHT_PROGBITS) {
      continue;
    }
    const uint32_t name_idx = section_header.sh_name();
    const char *section_name =
        reinterpret_cast<const char *>(shstrtab + name_idx);
    if (memcmp(section_name, sh_debug_info, strlen(sh_debug_info)) == 0) {
      return true;
    }
  }
  return false;
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

  ElfXX_Ehdr ehdr{};
  const char *shstr_start = nullptr;
  const uint8_t endianness = data[EI_DATA];
  if (endianness != ELFDATA2LSB && endianness != ELFDATA2MSB) {
    result.bin_type = BinaryType::Invalid;
    return result;
  }
  Endianness endian =
      (endianness == ELFDATA2LSB ? Endianness::Little : Endianness::Big);

  switch (data[EI_CLASS]) {
  case ELFCLASS32:
    ehdr = ElfXX_Ehdr{reinterpret_cast<const Elf32_Ehdr *>(data), endian};
    break;
  case ELFCLASS64:
    ehdr = ElfXX_Ehdr{reinterpret_cast<const Elf64_Ehdr *>(data), endian};
    break;
  default:
    return result;
  }

  const uint16_t e_type = ehdr.e_type();

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
  if (ehdr.e_shstrndx() == SHN_UNDEF)
    return result;
  shstr_start = reinterpret_cast<const char *>(
      data + get_section_header(ehdr, ehdr.e_shstrndx(), data).sh_offset());

  const size_t num_sections = ehdr.e_shnum();
  std::vector<ElfXX_Shdr> section_headers{};
  for (uint32_t i = 0; i < num_sections; i++) {
    ElfXX_Shdr shdr = get_section_header(ehdr, i, data);
    section_headers.emplace_back(std::move(shdr));
  }

  // extract build id and library depends
  auto build_id = get_elf_build_id(data, section_headers, shstr_start);
  if (type == BinaryType::Relocatable &&
      maybe_kernel_object(section_headers, shstr_start)) {
    type = BinaryType::KernelObject;
  } else {
    auto needed = get_elf_needed(data, section_headers, shstr_start);
    result.needed_libs = std::move(needed);
  }
  result.build_id = std::move(build_id);
  result.has_debug_info = is_debug_info_present(section_headers, shstr_start);
  return result;
}

inline static fs::path get_filename_from_build_id(const std::string &build_id,
                                                  const char *dst_path) {
  const std::string build_id_str{build_id};
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
  pid_t pid = fork();
  if (pid == 0) {
    execvp(path, argv);
  }
  // wait for the child process to exit
  int status = 0;
  waitpid(pid, &status, 0);
  return status;
}

int elf_copy_debug_symbols(const char *src_path, const char *dst_path,
                           int flags, GuardedSet<std::string> &symbols) {
  int fd = open(src_path, O_RDONLY, 0);
  if (fd < 0) {
    perror("open");
    return -1;
  }
  struct stat st;
  if (fstat(fd, &st) < 0) {
    perror("fstat");
    return -1;
  }
  const size_t size = st.st_size;
  MappedFile file{fd, size};
  std::vector<const char *> args{"", "--remove-section=.comment",
                                 "--remove-section=.note"};
  std::vector<const char *> extra_args{}; // for binutils
  args.reserve(8);
  extra_args.reserve(1);
  const char *data = static_cast<const char *>(file.addr());
  const ELFParseResult result = identify_binary_data(data, size);

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

  if (result.build_id.empty()) {
    // change to strip only
    flags |= AB_ELF_STRIP_ONLY;
    get_logger()->warning(fmt::format("No build id found in {0}", src_path));
    return -2;
  }

  if (!result.has_debug_info) {
    flags |= AB_ELF_STRIP_ONLY;
    get_logger()->warning(
        fmt::format("No debug symbols found in {0}", src_path));
    return -3;
  }
  const fs::path final_path =
      get_filename_from_build_id(result.build_id, dst_path);
  const fs::path final_prefix = final_path.parent_path();
  fs::create_directories(final_prefix);

  if (flags & AB_ELF_FIND_SO_DEPS) {
    symbols.insert(result.needed_libs.begin(), result.needed_libs.end());
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
    auto path = final_path.string();
    const char *args[] = {"objcopy", "--only-keep-debug", src_path,
                          path.c_str(), nullptr};
    return forked_execvp("objcopy", const_cast<char *const *>(args));
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
  int ret = chmod(final_path.c_str(), 0644);
  if (ret != 0) {
    return ret;
  }
  return chown(final_path.c_str(), 0, 0);
}

class ELFWorkerPool : public ThreadPool<std::string, int> {
public:
  ELFWorkerPool(const std::string symdir, bool collect_so_deps = false,
                bool strip_only = false)
      : ThreadPool<std::string, int>([&](const std::string src_path) {
          return elf_copy_debug_symbols(
              src_path.c_str(), m_symdir.c_str(),
              AB_ELF_USE_EU_STRIP |
                  (collect_so_deps ? AB_ELF_FIND_SO_DEPS : 0) |
                  (strip_only ? AB_ELF_STRIP_ONLY : 0),
              m_sodeps);
        }),
        m_symdir(symdir), m_sodeps() {}

  const std::unordered_set<std::string> get_sodeps() const {
    return m_sodeps.get_set();
  }

private:
  const std::string m_symdir;
  GuardedSet<std::string> m_sodeps;
};

int elf_copy_debug_symbols_parallel(const std::vector<std::string> &directories,
                                    const char *dst_path,
                                    std::unordered_set<std::string> &so_deps) {
  bool collect_so_deps = false;
  if (!so_deps.empty()) {
    collect_so_deps = true;
    so_deps.clear();
  }
  ELFWorkerPool pool{dst_path, collect_so_deps};
  for (const auto &directory : directories) {
    for (const auto &entry : fs::recursive_directory_iterator(directory)) {
      if (entry.is_regular_file() && (!entry.is_symlink())) {
        // queue the files
        pool.enqueue(static_cast<std::string>(entry.path().string()));
      }
    }
  }

  pool.wait_for_completion();
  const auto pool_results = pool.get_sodeps();

  if (pool.has_error())
    return 1;

  if (collect_so_deps)
    so_deps.insert(pool_results.begin(), pool_results.end());

  return 0;
}
