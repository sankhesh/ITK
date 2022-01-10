#
# Introduction
# ------------
#
# ITK IO factories can be registered automatically either "statically" or "dynamically".
#
# "statically" : This is the mechanism described below and supported by UseITK.
#
# "dynamically": This corresponds to the runtime loading of shared libraries
#                exporting the "itkLoad" symbol and available in directory
#                associated with the `ITK_AUTOLOAD_PATH` environment variable.
#
#
# Overview: Static registration of ITK IO factories
# -------------------------------------------------
#
# For each factory type (Image, Transform, Mesh, ...), a registration manager header
# named `itk<factory_type>IOFactoryRegisterManager.h` is configured.
#
# The registration manager header is itself included at the end of the Reader and
# Writer header of each factory types. It will ensure all the IO factories
# associated with the different file formats are registered only once by
# relying on static initialization of a global variable properly initialized
# by the loader across all translation units.
#
# By including either `itk<factory_type>FileReader.h` or `itk<factory_type>FileWriter.h`
# header in user code, the corresponding IO factories will be ensured to be
# registered globally and available across translation units.
#
# The file formats associated with each factory type are hard-coded as
# a list in a CMake variable named after `LIST_OF_<factory_type>IO_FORMATS`
# generated by this file.
#
#
# Registration manager header
# ---------------------------
#
# Configuration of the header requires two CMake variables to be set. The
# two variables `LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION` will
# respectively contain a list of function declaration and calls. The associated
# function names are of the form `<factory_name>FactoryRegister__Private`.
#
# These variables are set by iterating over the IO format lists.
#
#
# Disabling static registration
# -----------------------------
#
# Setting variable `ITK_NO_IO_FACTORY_REGISTER_MANAGER` to `OFF` prior calling
# `include(${ITK_USE_FILE})` disables the static registration. As a consequence,
# the two variables `LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION`
# are empty and no calls to "Private" function is done.
#
# IO format lists
# ---------------
#
# The IO format lists are CMake variables initialized when loading ITK modules.
# Each module is responsible for declaration of the image and transform formats that it
# implements.
#
# One list will be set for each factory type.
#
# Variable name is expected to be of the form `LIST_OF_<factory_type>IO_FORMATS`
# where `<factory_type>` is the upper-cased `factory_type`.
#
# Notes:
#
#  * The order of file format matters: Since it will define in which order
#    the different factories are registered, it will by extension defines the
#    "priority" for each file format.
#
#  * This list does not indicates which factory are registered: It should be
#    considered as a hint to indicate the order in which factory should
#    registered based on which ITK modules are used or imported within a
#    given project.
#
#
# The "Private" function
# ----------------------
#
# The function is responsible to register the IO factory for a given format
# associated with a specific factory type.
#
# It is defined in the `itk<format><factory_type>IOFactory.cxx` file and should
# internally call the function `<format><factory_type>IOFactory::RegisterOneFactory()`.
#
# The factory is then effectively registered in `RegisterOneFactory()` by calling
# `ObjectFactoryBase::RegisterFactoryInternal(<format><factory_type>IOFactory::New())`.
#
# Notes:
#
#  * the function will be available in both shared or static build case. Static
#    initialiation will happen in both cases.
#
#  * the function is unique and consistently named for each IO factory. The
#    current naming convention is an implementation detail and is not part
#    of the ITK Public API.
#
#
# Generation of "Private()" function lists
# ----------------------------------------
#
# The configuration of the registration header for each factory is done
# using the convenience function `_itk_configure_FactoryRegisterManager()`.
#
# It expects a list of file format associated with each factory types.
#
# By iterating over the format list, the CMake function `_itk_configure_FactoryRegisterManager()`
# will itself call `_itk_ADD_FACTORY_REGISTRATION()` to generate the Private function
# names and update the `LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION`
# CMake lists.
#
# Every file format is associated with a module name and factory name set
# by iterating over the list of file format prior the call to `_itk_configure_FactoryRegisterManager()`.
#
#
# Caveats
# -------
#
# Since the both include directory containing the registration manager headers
# and the `ITK_IO_FACTORY_REGISTER_MANAGER` COMPILE_DEFINITIONS are set as
# directory properties, including external project (themselves including ITK)
# after including ITK can have unintended side effects.
#



# _itk_configure_FactoryRegisterManager(<factory_type> <formats>)
#
# Configure the registration manager header in the directory
# `<CMAKE_CURRENT_BINARY_DIR>/ITKFactoryRegistration/`.
#
# Header is named using the template `itk<factory_type>FactoryRegisterManager.h`
#
function(_itk_configure_FactoryRegisterManager factory_type formats)
  set(LIST_OF_FACTORIES_REGISTRATION "")
  set(LIST_OF_FACTORY_NAMES "")
  string(TOLOWER ${factory_type} _qualifier)
  foreach (format ${formats})
    set(_module_name ${${format}_${_qualifier}_module_name})
    set(_factory_name ${${format}_${_qualifier}_factory_name})
    _itk_ADD_FACTORY_REGISTRATION("LIST_OF_FACTORIES_REGISTRATION" "LIST_OF_FACTORY_NAMES"
      ${_module_name} ${_factory_name})
  endforeach()

  # Special case: FFT::<format> inputs are for "<format>FFTImageFilter" classes
  if(factory_type STREQUAL "FFT")
    set(factory_type "FFTImageFilter")
  endif()

  configure_file(${ITK_CMAKE_DIR}/itk${factory_type}FactoryRegisterManager.h.in
   "${CMAKE_CURRENT_BINARY_DIR}/ITKFactoryRegistration/itk${factory_type}FactoryRegisterManager.h" @ONLY)

endfunction()

# _itk_ADD_FACTORY_REGISTRATION(<registration_list_var> <names_list_var> <module_name> <factory_name>)
#
# Update variables`LIST_OF_FACTORY_NAMES` and `LIST_OF_FACTORIES_REGISTRATION`
# used to configure `itk<factory_type>IOFactoryRegisterManager.h`.
#
macro(_itk_ADD_FACTORY_REGISTRATION _registration_list_var _names_list_var _module_name _factory_name)
  # note: this is an internal CMake variable and should not be used outside ITK
  set(_abi)
  if(${_module_name}_ENABLE_SHARED AND ITK_BUILD_SHARED)
    set(_abi "ITK_ABI_IMPORT")
  endif()

  # Special case: FFT::<format> inputs are for "<format>FFTImageFilter" classes
  if(_factory_name STREQUAL "FFT")
    set(_factory_name "FFTImageFilter")
  endif()

  set(${_registration_list_var}
    "${${_registration_list_var}}void ${_abi} ${_factory_name}FactoryRegister__Private();")
  set(${_names_list_var} "${${_names_list_var}}${_factory_name}FactoryRegister__Private,")
endmacro()

#-----------------------------------------------------------------------------
# Factory registration
#
# Arguments are factory names of factory registration mangers to be
# generated, if no arguments are provided then ITK_FACTORY_LIST is
# used for the list of managers generated.
#
#-----------------------------------------------------------------------------
macro(itk_generate_factory_registration)
  set(_factory_list ${ITK_FACTORY_LIST})

  set(variadic_args ${ARGN})
  list(LENGTH variadic_args _argc)
  if (${_argc} GREATER 0)
    set(_factory_list ${variadic_args})
  endif()
  foreach(_factory_name ${ITK_FACTORY_LIST})
    string(TOUPPER ${_factory_name} factory_uc)
    string(TOLOWER ${_factory_name} factory_lc)
    set(LIST_OF_${factory_uc}_FORMATS "")
    foreach(_format ${ITK_${_factory_name}})
      set(Module )
      foreach(_module ${ITK_FACTORY_NAMES})
        string(REGEX MATCH "^.*::${_factory_name}::${_format}$" Module_Matched "${_module}")
        if(Module_Matched)
          string(REGEX REPLACE "(.*)::${_factory_name}::${_format}" "\\1" Module "${Module_Matched}")
          break()
        endif()
      endforeach()
      if(NOT Module)
        message(FATAL_ERROR "Module not found for ${_factory_name} format \"${_format}\" in factory")
      endif()
      list(APPEND LIST_OF_${factory_uc}_FORMATS ${_format})
      set(${_format}_${factory_lc}_module_name ${Module})
      set(${_format}_${factory_lc}_factory_name ${_format}${_factory_name})
    endforeach()
    if(NOT ITK_NO_${factory_uc}_FACTORY_REGISTER_MANAGER)
      # pass generation IO factory registration
    elseif(_factory_name MATCHES "FFT" AND ITK_NO_FFT_FACTORY_REGISTER_MANAGER)
      # pass generation of FFT factory registration
    else()
      _itk_configure_FactoryRegisterManager("${_factory_name}" "${LIST_OF_${factory_uc}_FORMATS}")
    endif()
  endforeach()
endmacro()
