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
#include <algorithm>

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

// Loongson2F (MIPS-III)
constexpr uint32_t elf_flags_loongson2f = 0x20000007;

// Loongson3 (MIPS)
constexpr uint32_t elf_flags_loongson3 = 0x80a20007;

// MIPS64R6EL
constexpr uint32_t elf_flags_mips64r6el = 0xa0000407;

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
  ELFXX_ADD_GETTER(e_machine);
  ELFXX_ADD_GETTER(e_flags);
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

static const ElfXX_Shdr *
find_elf_section_header(const std::vector<ElfXX_Shdr> &section_headers,
                        const char *shstrtab,
                        const char *name,
                        const uint32_t type) {
  for (const auto &shdr : section_headers) {
    const uint32_t sh_type = shdr.sh_type();
    if (sh_type != type)
      continue;
    const uint32_t name_idx = shdr.sh_name();
    const char *section_name =
            reinterpret_cast<const char *>(shstrtab + name_idx);
    if (memcmp(section_name, name, strlen(name)) != 0)
      continue;
    return &shdr;
  }
  return nullptr;
}

static const char *
get_elf_dynstrtab(const char *file_start,
                  const std::vector<ElfXX_Shdr> &section_headers,
                  const char *shstrtab) {
  // constexpr const char *sh_dyn = ".dynamic";
  constexpr const char *sh_dynstr = ".dynstr";
  const auto shdr = find_elf_section_header(
          section_headers, shstrtab, sh_dynstr, SHT_STRTAB);
  if (shdr != nullptr) {
    return reinterpret_cast<const char *>(file_start) + shdr->sh_offset();
  } else {
    return nullptr;
  }
}

static std::vector<const char *>
get_elf_needed(const char *file_start,
               const std::vector<ElfXX_Shdr> &section_headers,
               const char *dynstrtab) {
  std::vector<const char *> needed{};
  if (dynstrtab == nullptr)
    return needed;
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
  // constexpr const char *sh_go_build_id = ".note.go.buildid";
  const auto section_header = find_elf_section_header(
          section_headers, shstrtab, sh_gnu_build_id, SHT_NOTE);
  if (section_header == nullptr)
    return build_id;
  const char *note_start = file_start + section_header->sh_offset();
  ElfXX_Nhdr note_header = {note_start, section_header->is_64bit(),
                            section_header->endianness()};
  const size_t header_size = note_header.size();
  const unsigned char *value =
      reinterpret_cast<const unsigned char *>(note_start) + header_size +
      note_header.n_namesz();
  for (size_t i = 0; i < note_header.n_descsz(); i++) {
    const unsigned char hi = table[(value[i] & 0xF0) >> 4];
    const unsigned char lo = table[(value[i] & 0x0F) >> 0];
    build_id += hi;
    build_id += lo;
  }

  return build_id;
}

static const uint64_t
decode_uleb128(const unsigned char *start, const size_t pos_max, size_t &pos) {
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

static const bool
is_null_terminated_string(const uint64_t tag) {
  // Tags with null-terminated string as values: 4: CPU_raw_name, 5: CPU_name, 67: conformance
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
static AOSCArch
get_elf_arm_arch(const char *file_start,
                 const std::vector<ElfXX_Shdr> &section_headers,
                 const char *shstrtab) {
  constexpr const char *sh_abi_tag = ".ARM.attributes";
  constexpr const char *vendor_name = "aeabi";
  bool hard_float = false;
  const auto vendor_name_len = strlen(vendor_name);
  auto ret = AOSCArch::NONE;
  const auto section_header = find_elf_section_header(
          section_headers, shstrtab, sh_abi_tag, SHT_ARM_ATTRIBUTES);
  if (section_header == nullptr)
    return ret;
  const unsigned char *start = reinterpret_cast<const unsigned char *>(file_start) + section_header->sh_offset();
  const auto size = section_header->sh_size();
  // Version identifier 'A'
  if (*start != 'A')
    return ret;
  size_t pos = 1;

  // Parse sections
  while (pos < size) {
    uint32_t section_length = *reinterpret_cast<const uint32_t *>(start + pos);
    if (section_header->endianness() == Endianness::Little) {
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
    uint32_t attributes_length = *reinterpret_cast<const uint32_t *>(start + pos + 1);
    if (pos + attributes_length > section_end)
      return AOSCArch::NONE;
    const size_t attributes_end = pos + attributes_length;
    pos += 5;

    // Parse attributes
    while (pos < attributes_end) {
      const auto tag = decode_uleb128(start, attributes_end, pos);
      if (is_null_terminated_string(tag)) {
        const size_t val_len = strlen(reinterpret_cast<const char*>(start) + pos);
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
  } else if (((ret == AOSCArch::ARMV6HF) || (ret == AOSCArch::ARMV7HF)) && (! hard_float)) {
    return AOSCArch::NONE;
  }
  return ret;
}

static std::string
get_elf_soname(const char *file_start,
               const std::vector<ElfXX_Shdr> &section_headers,
               const char *dynstrtab) {
  for (const ElfXX_Shdr &shdr : section_headers) {
    const uint32_t type = shdr.sh_type();
    // soname section is a dynamic section
    if (type != SHT_DYNAMIC) {
      continue;
    }
    const char *dyn_start =
            reinterpret_cast<const char *>(file_start) + shdr.sh_offset();
    const char *dyn_end = dyn_start + shdr.sh_size();
    while (dyn_start < dyn_end) {
      const auto dyn = ElfXX_Dyn{dyn_start, shdr.is_64bit(), shdr.endianness()};
      if (dyn.d_tag() == DT_SONAME) {
        const uint32_t name_idx = dyn.d_val();
        const char *section_name =
                reinterpret_cast<const char *>(dynstrtab + name_idx);
        return std::string{section_name};
      }
      dyn_start += dyn.size();
    }
  }
  return std::string{};
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
  constexpr const char *sh_debug_info = ".debug_";
  const size_t sh_debug_info_sz = strlen(sh_debug_info);
  for (const ElfXX_Shdr &section_header : section_headers) {
    const uint32_t name_idx = section_header.sh_name();
    const char *section_name =
        reinterpret_cast<const char *>(shstrtab + name_idx);
    if (strncmp(section_name, sh_debug_info, sh_debug_info_sz) == 0) {
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
  const Endianness endian =
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
    section_headers.emplace_back(shdr);
  }

  // extract build id and library depends
  const auto dynstrtab = get_elf_dynstrtab(data, section_headers, shstr_start);
  const auto build_id = get_elf_build_id(data, section_headers, dynstrtab);
  const auto soname = get_elf_soname(data, section_headers, dynstrtab);
  if (type == BinaryType::Relocatable &&
      maybe_kernel_object(section_headers, shstr_start)) {
    type = BinaryType::KernelObject;
  } else {
    auto needed = get_elf_needed(data, section_headers, dynstrtab);
    result.needed_libs = std::move(needed);
  }
  result.build_id = std::move(build_id);
  result.soname = std::move(soname);
  result.has_debug_info = is_debug_info_present(section_headers, shstr_start);

  // detect architecture
  switch (ehdr.e_machine()) {
  case EM_X86_64:
    result.arch = AOSCArch::AMD64;
    break;
  case EM_AARCH64:
    result.arch = AOSCArch::ARM64;
    break;
  case EM_ARM:
    // Checks .ARM.attributes
    result.arch = get_elf_arm_arch(data, section_headers, shstr_start);
    break;
  // Assumes EM_386 binaries are always i486-compatible
  case EM_386:
    result.arch = AOSCArch::I486;
    break;
  case EM_LOONGARCH:
    if (ehdr.is_64bit()) {
      result.arch = AOSCArch::LOONGARCH64;
    } else {
      result.arch = AOSCArch::NONE;
    }
    break;
  case EM_MIPS:
    // MIPS{32,64}BE aren't supported
    if (endian == Endianness::Big) {
      result.arch = AOSCArch::NONE;
      break;
    }
    // e_flags-based detection
    switch (ehdr.e_flags()) {
      case elf_flags_loongson2f:
        result.arch = AOSCArch::LOONGSON2F;
        break;
      case elf_flags_loongson3:
        result.arch = AOSCArch::LOONGSON3;
        break;
      case elf_flags_mips64r6el:
        result.arch = AOSCArch::MIPS64R6EL;
        break;
      default:
        result.arch = AOSCArch::NONE;
        break;
    }
    break;
  case EM_PPC:
    if (endian == Endianness::Big) {
      result.arch = AOSCArch::POWERPC;
    } else {
      result.arch = AOSCArch::NONE;
    }
    break;
  case EM_PPC64:
    if (endian == Endianness::Big) {
      result.arch = AOSCArch::PPC64;
    } else {
      result.arch = AOSCArch::PPC64EL;
    }
    break;
  case EM_RISCV:
    // TODO: Check RISC-V attributes for better accuracy
    if (ehdr.is_64bit()) {
      result.arch = AOSCArch::RISCV64;
    } else {
      result.arch = AOSCArch::NONE;
    }
    break;
  case EM_SPARCV9:
    result.arch = AOSCArch::SPARC64;
    break;
  default:
    result.arch = AOSCArch::NONE;
    break;
  }

  return result;
}

inline static fs::path get_filename_from_build_id(const std::string &build_id,
                                                  const char *dst_path) {
  const std::string& build_id_str{build_id};
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

int elf_copy_debug_symbols(const char *src_path, const char *dst_path,
                           int flags, GuardedSet<std::string> &symbols,
                           GuardedSet<std::string> &sonames) {
  int fd = open(src_path, O_RDONLY, 0);
  if (fd < 0) {
    perror("open");
    return -1;
  }
  struct stat st{};
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
  if ((flags & AB_ELF_FIND_SONAMES) && in_usr_lib && (! result.soname.empty())) {
      sonames.emplace(result.soname);
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
    get_logger()->warning(fmt::format("No build id found in {0}. Saving with relative path", src_path));
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
  ELFWorkerPool(std::string  symdir, int flags)
      : ThreadPool<std::string, int>([&, flags](const std::string& src_path) {
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
