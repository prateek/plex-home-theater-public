# vim: setlocal syntax=cmake:

set(CMAKE_REQUIRED_INCLUDES ${dependdir}/include ${root}/lib/ffmpeg)

if(UNIX)
  set(CMAKE_REQUIRED_FLAGS "-D__LINUX_USER__")
endif()

include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckSymbolExists)
include(CheckLibraryExists)
include(CheckCSourceCompiles)

set(AC_APPLE_UNIVERSAL_BUILD 0)
set(HAS_DVD_DRIVE 0)
set(HAS_LIBRTMP 1)

######################### CHECK HEADER
set(headers
  arpa/inet
  cdio/iso9660
  dirent
  fcntl
  float
  inttypes
  limits
  locale
  malloc
  memory
  ndir
  netdb
  netinet/in
  nfsc/libfs
  stdbool
  stddef
  stdint
  stdlib
  strings
  string
  sys/dir
  sys/file
  sys/ioctl
  sys/mount
  sys/ndir
  sys/param
  sys/select
  sys/socket
  sys/stat
  sys/timeb
  sys/time
  sys/types
  sys/vfs
  termios
  unistd
  utime
  wchar
  wctype
  
 # libcrystalHD
  libcrystalhd/libcrystalhd_if
)

foreach(header ${headers})
  set(_HAVE_VAR HAVE_${header}_H)
  string(TOUPPER ${_HAVE_VAR} _HAVE_VAR)
  string(REPLACE "/" "_" _HAVE_VAR ${_HAVE_VAR})
  check_include_files(${header}.h ${_HAVE_VAR})
endforeach()

######################### CHECK FUNCTIONS 
set(functions
  alarm
  atexit
  chown
  _doprnt
  dup2
  fdatasync
  floor
  fs_stat_dev
  ftime
  ftruncate
  getcwd
  gethostbyaddr
  gethostbyname
  getpagesize
  getpass
  gettimeofday
  inet_ntoa
  inotify
  lchown
  localeconv
  memchr
  memmove
  mkdir
  modf
  mmap
  munmap
  pow
  rmdir
  select
  setenv
  setlocale
  socket
  sqrt
  strcasecmp
  strchr
  strcoll
  strcspn
  strdup
  strerror
  strftime
  strncasecmp
  strpbrk
  strrchr
  strspn
  strstr
  strtol
  strtoul
  sysinfo
  tzset
  utime
  vprintf
)

foreach(func ${functions})
  set(_HAVE_VAR HAVE_${func})
  string(TOUPPER ${_HAVE_VAR} _HAVE_VAR)
  check_function_exists(${func} ${_HAVE_VAR})
endforeach()

######################### CHECK LIBRARIES / FRAMEWORKS
#### Frameworks for MacOSX
if(APPLE)
	set(osx_frameworks
		AudioToolbox
		AudioUnit
		Cocoa
		CoreAudio
		CoreServices
		Foundation
		OpenGL
		AppKit
		ApplicationServices
		IOKit
		QuickTime
		Carbon
		DiskArbitration
		QuartzCore
		SystemConfiguration
    IOSurface
	)
endif()

#### libraries we want to link to
if(NOT WIN32)
  set(external_libs
    ssh
    lzo2
    pcre
    pcrecpp
    fribidi
    cdio
    freetype
    fontconfig
    sqlite3
    samplerate
    microhttpd
    yajl
    jpeg
    crypto
    SDL
    SDL_mixer
    SDL_image
    tinyxml
    boost_thread
    boost_system
    z
    GLEW
  
    # ffmpeg libraries
    avcodec
    avutil
    avformat
    avfilter
    avdevice
    postproc
    swscale
    swresample
  )
  if(NOT APPLE)
    list(APPEND external_libs GL)
    list(APPEND external_libs X11)
  endif()
endif()

if(WIN32)
  set(system_libs
    D3dx9
    DInput8
    DSound
    winmm
    Mpr
    Iphlpapi
    PowrProf
    setupapi
    dwmapi
    yajl
    dxguid
    DxErr
    Delayimp
  )

  set(external_libs
    libfribidi
    libiconv
    turbojpeg-static
    libmicrohttpd.dll
    ssh
    freetype246MT
    sqlite3
    liblzo2
    dnssd
    libcdio.dll
    zlib
    libsamplerate-0
  )

  set(non_link_libs
    SDL
    SDL_image
  )

  if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
    set(external_libs ${external_libs} tinyxmlSTLd libboost_thread-vc100-mt-sgd-1_46_1 libboost_system-vc100-mt-sgd-1_46_1)
  else()
    set(external_libs ${external_libs} tinyxmlSTL libboost_thread-vc100-mt-s-1_46_1 libboost_system-vc100-mt-s-1_46_1)
  endif()
else()
  set(non_link_libs
    rtmp
    plist
    shairport
    curl
    FLAC
    modplug
    vorbis
    vorbisfile
    vorbisenc
    ogg
    ass
    mad
    mpeg2
    bluray
    png
    tiff
  )
  if(APPLE)
    list(APPEND non_link_libs cec)
  endif()
endif()

set(CONFIG_INTERNAL_LIBS
  lib_hts
  lib_squish
  lib_upnp
)

if(APPLE)
  # on darwin we use the built in iconv
  list(APPEND system_libs iconv)

  # also add apple libstdc++
  list(APPEND system_libs stdc++)
elseif(UNIX)
  # otherwise use our own version
  list(APPEND external_libs iconv)
endif()

# function to find library and set the variables we need
macro(plex_find_library lib framework nodefaultpath searchpath addtolinklist)
  string(TOUPPER ${lib} LIBN)

  # find the library, just searching in our paths
  if(${nodefaultpath})
    find_library(CONFIG_LIBRARY_${LIBN} ${lib} PATHS ${searchpath} ${searchpath}64 NO_DEFAULT_PATH)
  else()
    find_library(CONFIG_LIBRARY_${LIBN} ${lib} PATHS ${searchpath})
  endif()

  if(CONFIG_LIBRARY_${LIBN} MATCHES "NOTFOUND")
      message("** Could not detect ${LIBN}")
  else()
      # get the actual value
      get_property(l VARIABLE PROPERTY CONFIG_LIBRARY_${LIBN})
      
      # resolve any symlinks
      get_filename_component(REALNAME ${l} REALPATH)

      # split out the library name
      get_filename_component(FNAME ${REALNAME} NAME)
      
      # set the SONAME variable, needed for DllPaths_generated.h
      set(${LIBN}_SONAME ${FNAME} CACHE string "the soname for the current library")
      set(LIB${LIBN}_SONAME ${FNAME} CACHE string "the soname for the current library")
      
      # set the HAVE_LIBX variable
      set(HAVE_LIB${LIBN} 1 CACHE string "the HAVE_LIBX variable")
      
      # if this is a framework we need to mark it as advanced
      if(${framework})
        mark_as_advanced(CONFIG_LIBRARY_${LIBN})
      endif()
      
      if(${addtolinklist})
        list(APPEND CONFIG_PLEX_LINK_LIBRARIES ${l})
      else()
        list(APPEND CONFIG_PLEX_INSTALL_LIBRARIES ${REALNAME})
      endif()
  endif()
endmacro()
  

# go through all the libs we need and find them plus set some good variables
foreach(lib ${external_libs})
  plex_find_library(${lib} 0 1 ${dependdir}/lib 1)
endforeach()

foreach(lib ${non_link_libs})
  plex_find_library(${lib} 0 1 ${dependdir}/lib 0)
endforeach()

# find our system libs
foreach(lib ${system_libs})
  plex_find_library(${lib} 0 0 "" 1)
endforeach()

foreach(lib ${osx_frameworks})
  plex_find_library(${lib} 1 0 ${dependdir}/Frameworks 1)
endforeach()

####
if(DEFINED HAVE_LIBX11)
  set(HAVE_X11 1)
endif()

if(DEFINED HAVE_LIBSDL)
  set(HAVE_SDL 1)
endif()

set(USE_UPNP 1)

#### check FFMPEG member name
if(DEFINED HAVE_LIBAVFILTER_AVFILTER_H)
  set(AVFILTER_INC "#include <libavfilter/avfilter.h>")
else()
  set(AVFILTER_INC "#include <ffmpeg/avfilter.h>")
endif()
CHECK_C_SOURCE_COMPILES("
  ${AVFILTER_INC}
  int main(int argc, char *argv[])
  { 
    static AVFilterBufferRefVideoProps test;
    if(sizeof(test.sample_aspect_ratio))
      return 0;
    return 0;
  }
"
HAVE_AVFILTERBUFFERREFVIDEOPROPS_SAMPLE_ASPECT_RATIO)

if(DEFINED HAVE_LIBCRYSTALHD_LIBCRYSTALHD_IF_H)
  CHECK_C_SOURCE_COMPILES("
    #include <libcrystalhd/bc_dts_types.h>
    #include <libcrystalhd/bc_dts_defs.h>
    PBC_INFO_CRYSTAL bCrystalInfo;
    int main() {}
  " CHECK_CRYSTALHD_VERSION)
  if(CHECK_CRYSTALHD_VERSION)
    set(HAVE_LIBCRYSTALHD 2)
  else()
    set(HAVE_LIBCRYSTALHD 1)
  endif()
endif()

#### default lircdevice
set(LIRC_DEVICE "/dev/lircd")

#### Deal with some generated files
set(PLEX_TARGET_NAME PlexHomeTheater)
if(APPLE)
  set(EXECUTABLE_NAME "Plex Home Theater")
elseif(WIN32)
  set(EXECUTABLE_NAME "PlexHomeTheater")
else()
  set(EXECUTABLE_NAME "plexhometheater")
endif()

if(APPLE)
  set(ARCH "x86-osx")
elseif(UNIX)
  if(${CMAKE_HOST_SYSTEM_PROCESSOR} STREQUAL "x86_64")
    set(ARCH "x86_64-linux")
  else()
    set(ARCH "i486-linux")
  endif()
endif()

if(APPLE)
  set(LIBPATH "${EXECUTABLE_NAME}.app/Contents/Frameworks")
  set(BINPATH "${EXECUTABLE_NAME}.app/Contents/MacOSX")
  set(RESOURCEPATH "${EXECUTABLE_NAME}.app/Contents/Resources")
  set(HAVE_LIBVDADECODER 1)
elseif(UNIX)
  set(LIBPATH bin)
  set(BINPATH bin)
  set(RESOURCEPATH share)
else()
  set(LIBPATH .)
  set(BINPATH .)
  set(RESOURCEPATH .)
endif()

configure_file(${root}/xbmc/DllPaths_generated.h.in ${CMAKE_BINARY_DIR}/xbmc/DllPaths_generated.h)
configure_file(${plexdir}/config.h.in ${CMAKE_BINARY_DIR}/xbmc/config.h)