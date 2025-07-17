package libstemmer_vs_helpers;

use strict;
use warnings;
use Exporter qw(import);
use File::Path qw(make_path);
use File::Basename;
use File::Copy;

our @EXPORT = qw(
    process_runtime_header
    process_api_h
    process_api_c
    process_utilities_c
    process_libstemmer_h
    process_header_file
    process_source_file
    create_stemmer_exports_h
    create_build_config_h
);

# Create the stemmer_exports.h file with export macros
sub create_stemmer_exports_h {
    my ($output_dir) = @_;
    
    my $exports_header_dir = "$output_dir/include";
    make_path($exports_header_dir) unless -d $exports_header_dir;
    
    my $exports_file = "$exports_header_dir/stemmer_exports.h";
    
    # Check if the file already exists
    if (-f $exports_file) {
        print "stemmer_exports.h already exists, updating it...\n";
    } else {
        print "Creating stemmer_exports.h with export macro definitions...\n";
    }
    
    open my $exp_file, '>', $exports_file or die "Cannot create stemmer_exports.h: $!";
    print $exp_file <<'EXPORTS_HEADER';
/*
 * Header file defining export macros for libstemmer
 * 
 * STEMMER_API_PUBLIC is used for the 5 main API functions that should be exported in DLL builds
 * STEMMER_API is used for all other functions
 */
#ifndef STEMMER_EXPORTS_H
#define STEMMER_EXPORTS_H

#include "build_config.h"

#ifdef _WIN32
  #ifdef BUILDING_LIBSTEMMER
    #ifdef STEMMER_DYNAMIC
      /* When building DLL */
      #define STEMMER_API
      #define STEMMER_API_PUBLIC __declspec(dllexport)
    #else
      /* When building static library */
      #define STEMMER_API __declspec(dllexport)
      #define STEMMER_API_PUBLIC __declspec(dllexport)
    #endif
  #else
    /* When consuming the library */
    #ifdef STEMMER_DYNAMIC
      #define STEMMER_API
      #define STEMMER_API_PUBLIC __declspec(dllimport)
    #else
      #define STEMMER_API
      #define STEMMER_API_PUBLIC
    #endif
  #endif
#else
  /* Non-Windows platforms */
  #define STEMMER_API
  #define STEMMER_API_PUBLIC
#endif

#endif /* STEMMER_EXPORTS_H */
EXPORTS_HEADER
    close $exp_file;
    print "Created/updated stemmer_exports.h successfully\n";
}

# Create build_config.h with build configuration macros
sub create_build_config_h {
    my ($output_dir) = @_;
    
    my $include_dir = "$output_dir/include";
    make_path($include_dir) unless -d $include_dir;
    
    my $config_file_path = "$include_dir/build_config.h";
    
    # Check if the file already exists
    if (-f $config_file_path) {
        print "build_config.h already exists, updating it...\n";
    } else {
        print "Creating build_config.h with build configuration macros...\n";
    }
    
    open my $config_file, '>', $config_file_path or die "Cannot create build_config.h: $!";
    print $config_file <<'CONFIG_HEADER';
#ifndef __BUILD_CONFIG_H
#define __BUILD_CONFIG_H

#define BUILDING_LIBSTEMMER

/* Define STEMMER_DYNAMIC when building DLL configurations */
#if defined(_DLL) || defined(_WINDLL) || defined(_USRDLL)
#  define STEMMER_DYNAMIC
#endif

#endif /* __BUILD_CONFIG_H */
CONFIG_HEADER
    close $config_file;
    print "Created/updated build_config.h successfully\n";
}

# Process runtime/header.h to modify among struct and find_among declarations
sub process_runtime_header {
    my ($header_file, $output_dir) = @_;
    
    print "Processing $header_file to modify struct among and function declarations...\n";
    
    # Read the original file
    open my $in, '<', $header_file or die "Cannot open $header_file: $!";
    my $content = do { local $/; <$in> };
    close $in;
    
    my $dir = dirname("$output_dir/$header_file");
    make_path($dir) unless -d $dir;
    
    # Add stdint.h include to the file
    if ($content !~ /#include\s+<stdint\.h>/) {
        $content = "#include <stdint.h> /* for intptr_t type */\n\n" . $content;
    }
    
    # Remove any existing STEMMER_EXPORTDEFS definitions
    $content =~ s/#ifndef\s+STEMMER_EXPORTDEFS.*?#endif\s*\n//s;
    
    # Add include for stemmer_exports.h
    if ($content !~ /#include\s+["<].*stemmer_exports\.h[">]/) {
        $content = "#include \"include/stemmer_exports.h\"\n\n" . $content;
    }
    
    # Add macros for function calls with 3 parameters
    if ($content !~ /#define\s+find_among\(/) {
        my $macros = "/* Macros to handle the optional parameter in find_among functions */\n";
        $macros .= "#ifdef _MSC_VER\n";
        $macros .= "#define find_among(a,b,c) find_among_impl(a,b,c,0)\n";
        $macros .= "#define find_among_b(a,b,c) find_among_b_impl(a,b,c,0)\n";
        $macros .= "#endif\n\n";
        
        # Find a good place to insert the macros
        if ($content =~ /^(.*?)(?:#include|typedef|struct|extern)/s) {
            my $pos = length($1);
            $content = substr($content, 0, $pos) . $macros . substr($content, $pos);
        } else {
            $content = $macros . $content;
        }
    }
    
    # Modify struct among to use intptr_t for function
    my $found_among_struct = 0;
    if ($content =~ /struct\s+among\s*\{.*?int\s+function;.*?\};/s) {
        $content =~ s/(struct\s+among\s*\{.*?)int\s+function;(.*?\};)/$1intptr_t function; \/* function pointer *\/$2/s;
        $found_among_struct = 1;
    }
    
    # Replace find_among declaration
    my $found_find_among = 0;
    if ($content =~ /extern\s+int\s+find_among\s*\(.*?\);/s) {
        $content =~ s/extern\s+int\s+find_among\s*\(.*?\);/extern STEMMER_API int find_among_impl(struct SN_env * z, const struct among * v, int v_size, intptr_t f);/s;
        $found_find_among = 1;
    }
    
    # Replace find_among_b declaration
    my $found_find_among_b = 0;
    if ($content =~ /extern\s+int\s+find_among_b\s*\(.*?\);/s) {
        $content =~ s/extern\s+int\s+find_among_b\s*\(.*?\);/extern STEMMER_API int find_among_b_impl(struct SN_env * z, const struct among * v, int v_size, intptr_t f);/s;
        $found_find_among_b = 1;
    }
    
    # Replace any remaining extern declarations with extern STEMMER_API
    $content =~ s/extern\s+(?!STEMMER_API)/extern STEMMER_API /g;
    
    # Remove any remaining STEMMER_EXPORTDEFS
    $content =~ s/STEMMER_EXPORTDEFS\s+//g;
    
    # Write the modified content to the output file
    open my $out, '>', "$output_dir/$header_file" or die "Cannot create $output_dir/$header_file: $!";
    print $out $content;
    close $out;
    
    # Report on what was found and modified
    if ($found_among_struct) {
        print "  Successfully modified struct among to use intptr_t for function field\n";
    } else {
        print "  WARNING: Could not find struct among definition\n";
    }
    
    if ($found_find_among) {
        print "  Replaced find_among declaration with find_among_impl\n";
    } else {
        print "  WARNING: Could not find find_among declaration\n";
    }
    
    if ($found_find_among_b) {
        print "  Replaced find_among_b declaration with find_among_b_impl\n";
    } else {
        print "  WARNING: Could not find find_among_b declaration\n";
    }
    
    print "Successfully processed $header_file\n";
}

# Process api.h to modify SN_env struct
sub process_api_h {
    my ($api_h_file, $output_dir) = @_;
    
    print "Processing $api_h_file to modify struct SN_env...\n";
    
    # Check if the file exists
    unless (-f $api_h_file) {
        print "  WARNING: $api_h_file not found\n";
        return;
    }
    
    # Read the original file
    open my $in, '<', $api_h_file or die "Cannot open $api_h_file: $!";
    my $content = do { local $/; <$in> };
    close $in;
    
    my $dir = dirname("$output_dir/$api_h_file");
    make_path($dir) unless -d $dir;
    
    # Add stdint.h include to the file
    if ($content !~ /#include\s+<stdint\.h>/) {
        $content = "#include <stdint.h> /* for intptr_t type */\n\n" . $content;
    }
    
    # Modify struct SN_env to use intptr_t for af
    my $found_sn_env_struct = 0;
    if ($content =~ /struct\s+SN_env\s*\{.*?int\s+af;.*?\};/s) {
        $content =~ s/(struct\s+SN_env\s*\{.*?)int\s+af;(.*?\};)/$1intptr_t af; \/* function pointer *\/$2/s;
        $found_sn_env_struct = 1;
    }
    
    # Remove any existing STEMMER_EXPORTDEFS definitions
    $content =~ s/#ifndef\s+STEMMER_EXPORTDEFS.*?#endif\s*\n//s;
    
    # Add include for stemmer_exports.h
    if ($content !~ /#include\s+["<].*stemmer_exports\.h[">]/) {
        $content = "#include \"include/stemmer_exports.h\"\n\n" . $content;
    }
    
    # Write the modified content to the output file
    open my $out, '>', "$output_dir/$api_h_file" or die "Cannot create $output_dir/$api_h_file: $!";
    print $out $content;
    close $out;
    
    # Report on what was found and modified
    if ($found_sn_env_struct) {
        print "  Successfully modified struct SN_env to use intptr_t for af field\n";
    } else {
        print "  WARNING: Could not find struct SN_env definition\n";
    }
    
    print "Successfully processed $api_h_file\n";
}

# Process libstemmer.h to add exports to the main API functions
sub process_libstemmer_h {
    my ($libstemmer_h_file, $output_dir) = @_;
    
    print "Processing $libstemmer_h_file to add export declarations to main API functions...\n";
    
    # Check if the file exists
    unless (-f $libstemmer_h_file) {
        print "  WARNING: $libstemmer_h_file not found\n";
        return;
    }
    
    # Read the entire file content first
    open my $in, '<', $libstemmer_h_file or die "Cannot open $libstemmer_h_file: $!";
    my $content = do { local $/; <$in> };
    close $in;
    
    # Create output directory
    my $dir = dirname("$output_dir/$libstemmer_h_file");
    make_path($dir) unless -d $dir;
    
    # Remove any existing STEMMER_EXPORTDEFS definitions
    $content =~ s/#ifndef\s+STEMMER_EXPORTDEFS.*?#endif\s*\n//s;
    
    # Add include for stemmer_exports.h at the top
    if ($content !~ /#include\s+"stemmer_exports\.h"/) {
        if ($content =~ /^(.*?)(#include\s+.*$)/sm) {
            # Insert before the first include
            $content = $1 . "#include \"include/stemmer_exports.h\"\n\n" . $2;
        } else {
            # No includes found, add at the top
            $content = "#include \"include/stemmer_exports.h\"\n\n" . $content;
        }
        print "  Added include for stemmer_exports.h\n";
    }
    
    # Define the key API functions that need export declarations
    my @api_functions = (
        'sb_stemmer_list',
        'sb_stemmer_new',
        'sb_stemmer_delete',
        'sb_stemmer_stem',
        'sb_stemmer_length'
    );
    
    my $modified_count = 0;
    
    # Process each API function - use STEMMER_API_PUBLIC
    foreach my $func (@api_functions) {
        # Create specific pattern for each function
        my $pattern;
        
        if ($func eq 'sb_stemmer_list') {
            $pattern = qr/(\bconst\s+char\s*\*\*\s*sb_stemmer_list\s*\([^)]*\)\s*;)/;
            my $check_pattern = qr/STEMMER_API_PUBLIC\s*\bconst\s+char\s*\*\*\s*sb_stemmer_list/;
            if ($content =~ $pattern && $content !~ $check_pattern) {
                # Remove any existing STEMMER_API if present
                $content =~ s/STEMMER_API(?:_MAIN)?\s*\bconst\s+char\s*\*\*\s*sb_stemmer_list/const char ** sb_stemmer_list/g;
                $content =~ s/$pattern/STEMMER_API_PUBLIC $1/g;
                print "  Added STEMMER_API_PUBLIC to $func\n";
                $modified_count++;
            }
        }
        elsif ($func eq 'sb_stemmer_new') {
            $pattern = qr/(\bstruct\s+sb_stemmer\s*\*\s*sb_stemmer_new\s*\([^)]*\)\s*;)/;
            my $check_pattern = qr/STEMMER_API_PUBLIC\s*\bstruct\s+sb_stemmer\s*\*\s*sb_stemmer_new/;
            if ($content =~ $pattern && $content !~ $check_pattern) {
                # Remove any existing STEMMER_API if present
                $content =~ s/STEMMER_API(?:_MAIN)?\s*\bstruct\s+sb_stemmer\s*\*\s*sb_stemmer_new/struct sb_stemmer * sb_stemmer_new/g;
                $content =~ s/$pattern/STEMMER_API_PUBLIC $1/g;
                print "  Added STEMMER_API_PUBLIC to $func\n";
                $modified_count++;
            }
        }
        elsif ($func eq 'sb_stemmer_delete') {
            $pattern = qr/(\bvoid\s+sb_stemmer_delete\s*\([^)]*\)\s*;)/;
            my $check_pattern = qr/STEMMER_API_PUBLIC\s*\bvoid\s+sb_stemmer_delete/;
            if ($content =~ $pattern && $content !~ $check_pattern) {
                # Remove any existing STEMMER_API if present
                $content =~ s/STEMMER_API(?:_MAIN)?\s*\bvoid\s+sb_stemmer_delete/void sb_stemmer_delete/g;
                $content =~ s/$pattern/STEMMER_API_PUBLIC $1/g;
                print "  Added STEMMER_API_PUBLIC to $func\n";
                $modified_count++;
            }
        }
        elsif ($func eq 'sb_stemmer_stem') {
            $pattern = qr/(\bconst\s+sb_symbol\s*\*\s*sb_stemmer_stem\s*\([^)]*\)\s*;)/;
            my $check_pattern = qr/STEMMER_API_PUBLIC\s*\bconst\s+sb_symbol\s*\*\s*sb_stemmer_stem/;
            if ($content =~ $pattern && $content !~ $check_pattern) {
                # Remove any existing STEMMER_API if present
                $content =~ s/STEMMER_API(?:_MAIN)?\s*\bconst\s+sb_symbol\s*\*\s*sb_stemmer_stem/const sb_symbol * sb_stemmer_stem/g;
                $content =~ s/$pattern/STEMMER_API_PUBLIC $1/g;
                print "  Added STEMMER_API_PUBLIC to $func\n";
                $modified_count++;
            }
        }
        elsif ($func eq 'sb_stemmer_length') {
            $pattern = qr/(\bint\s+sb_stemmer_length\s*\([^)]*\)\s*;)/;
            my $check_pattern = qr/STEMMER_API_PUBLIC\s*\bint\s+sb_stemmer_length/;
            if ($content =~ $pattern && $content !~ $check_pattern) {
                # Remove any existing STEMMER_API if present
                $content =~ s/STEMMER_API(?:_MAIN)?\s*\bint\s+sb_stemmer_length/int sb_stemmer_length/g;
                $content =~ s/$pattern/STEMMER_API_PUBLIC $1/g;
                print "  Added STEMMER_API_PUBLIC to $func\n";
                $modified_count++;
            }
        }
    }
    
    # Remove any remaining STEMMER_EXPORTDEFS or old API macros
    $content =~ s/STEMMER_EXPORTDEFS\s+//g;
    $content =~ s/STEMMER_API_MAIN\s+/STEMMER_API_PUBLIC /g;
    
    # Write the modified content back to the file
    open my $out, '>', "$output_dir/$libstemmer_h_file" or die "Cannot create $output_dir/$libstemmer_h_file: $!";
    print $out $content;
    close $out;
    
    if ($modified_count > 0) {
        print "Successfully processed $libstemmer_h_file ($modified_count API functions modified)\n";
    } else {
        print "WARNING: Could not find any API functions to modify in $libstemmer_h_file\n";
    }
    
    print "API functions now use STEMMER_API_PUBLIC for conditional export in DLL builds\n";
}

# Process runtime/api.c to modify function implementations
sub process_api_c {
    my ($api_c_file, $output_dir) = @_;
    
    print "Processing $api_c_file to modify function implementations...\n";
    
    # Read the original file
    open my $in, '<', $api_c_file or die "Cannot open $api_c_file: $!";
    my $content = do { local $/; <$in> };
    close $in;
    
    my $dir = dirname("$output_dir/$api_c_file");
    make_path($dir) unless -d $dir;
    
    # Fix empty struct initialization
    my $found_empty_struct = 0;
    if ($content =~ /static\s+const\s+struct\s+SN_env\s+default_SN_env\s+=\s+\{\};/) {
        $content =~ s/static\s+const\s+struct\s+SN_env\s+default_SN_env\s+=\s+\{\};/static const struct SN_env default_SN_env = {0}; \/* Fixed for Visual Studio *\//g;
        $found_empty_struct = 1;
    }
        
    # Write the modified content to the output file
    open my $out, '>', "$output_dir/$api_c_file" or die "Cannot create $output_dir/$api_c_file: $!";
    print $out $content;
    close $out;
    
    # Report on what was found and modified
    if ($found_empty_struct) {
        print "  Fixed empty struct initialization\n";
    }
    
    print "Successfully processed $api_c_file\n";
}

# Process utilities.c to check for find_among implementations
sub process_utilities_c {
    my ($utilities_c_file, $output_dir) = @_;
    
    print "Processing $utilities_c_file to check for find_among implementations...\n";
    
    # Try different path variations to find the file
    my @possible_paths = ($utilities_c_file, "runtime/$utilities_c_file", "src/$utilities_c_file");
    my $found_file = undef;
    
    foreach my $path (@possible_paths) {
        if (-f $path) {
            $found_file = $path;
            print "  Found utilities.c at: $path\n";
            last;
        }
    }
    
    unless ($found_file) {
        print "  WARNING: utilities.c not found in expected locations\n";
        print "  Searching for the file...\n";
        
        # Try to find the file by scanning directories
        my @found_files = `find . -name "utilities.c" 2>/dev/null`;
        if (@found_files) {
            chomp($found_files[0]);
            $found_file = $found_files[0];
            $found_file =~ s/^\.\///; # Remove leading ./
            print "  Found utilities.c at: $found_file\n";
        } else {
            print "  ERROR: Could not find utilities.c\n";
            return;
        }
    }
    
    # Read the original file
    open my $in, '<', $found_file or die "Cannot open $found_file: $!";
    my $content = do { local $/; <$in> };
    close $in;
    
    # Prepare output path
    my $output_path = "$output_dir/$found_file";
    my $dir = dirname($output_path);
    make_path($dir) unless -d $dir;
    
    # Explicitly rename find_among to find_among_impl
    my $found_find_among = 0;
    if ($content =~ /\bint\s+find_among\s*\(/) {
        $content =~ s/\bint\s+find_among\s*\(/int find_among_impl\(/g;
        $found_find_among = 1;
    }
    
    # Explicitly rename find_among_b to find_among_b_impl
    my $found_find_among_b = 0;
    if ($content =~ /\bint\s+find_among_b\s*\(/) {
        $content =~ s/\bint\s+find_among_b\s*\(/int find_among_b_impl\(/g;
        $found_find_among_b = 1;
    }
    
    # Fix parameter types in function definitions
    $content =~ s/\bint\s+\(\*call_among_func\)\(struct\s+SN_env\*\)/intptr_t f/g;
    
    # Fix function pointer calls
    $content =~ s/if\s*\(call_among_func\(z\)\)/if \(\(\(int \(\*\)\(struct SN_env\*\)\)f\)\(z\)\)/g;
    $content =~ s/v\[i\]\.function\(z\)/\(\(int \(\*\)\(struct SN_env \*\)\)v\[i\].function\)\(z\)/g;
    
    # Add explicit casts to function pointers in struct initializations
    if ($content =~ /static\s+const\s+struct\s+among/) {
        print "  Adding casts to function pointers in struct initializations\n";
        $content =~ s/(\{\s*\d+\s*,\s*\w+\s*,\s*[-\d]+\s*,\s*[-\d]+\s*,\s*)([a-zA-Z_][a-zA-Z0-9_]*)(\s*\})/$1(intptr_t)$2$3/g;
    }
    
    # Write the modified content
    open my $out, '>', $output_path or die "Cannot create $output_path: $!";
    print $out $content;
    close $out;
    
    # Report what was found and modified
    if ($found_find_among) {
        print "  Renamed find_among to find_among_impl\n";
    } else {
        print "  WARNING: Could not find find_among implementation\n";
    }
    
    if ($found_find_among_b) {
        print "  Renamed find_among_b to find_among_b_impl\n";
    } else {
        print "  WARNING: Could not find find_among_b implementation\n";
    }
    
    print "Successfully processed $found_file\n";
}

# Function to process a regular header file and add export declarations
sub process_header_file {
    my ($header_file, $output_dir) = @_;
    
    # Special handling for runtime/header.h
    if ($header_file eq "runtime/header.h") {
        return process_runtime_header($header_file, $output_dir);
    }
    
    # Special handling for api.h
    if ($header_file eq "api.h" || $header_file =~ /\bapi\.h$/) {
        return process_api_h($header_file, $output_dir);
    }
    
    # Special handling for libstemmer.h
    if ($header_file eq "libstemmer.h" || $header_file =~ /\blibstemmer\.h$/) {
        return process_libstemmer_h($header_file, $output_dir);
    }
    
    my $basename = basename($header_file);
    my $guard_name = uc($basename);
    $guard_name =~ s/[^a-zA-Z0-9]/_/g;
    $guard_name = "__${guard_name}_H";
    
    print "Processing $header_file (using guard: $guard_name)...\n";
    
    # Process normal header files
    open my $in, '<', $header_file or die "Cannot open $header_file: $!";
    my $original_content = do { local $/; <$in> };
    close $in;
    
    my $dir = dirname("$output_dir/$header_file");
    make_path($dir) unless -d $dir;
    
    open my $out, '>', "$output_dir/$header_file" or die "Cannot create $output_dir/$header_file: $!";
    
    # Check if file already has the header guard
    my $has_header_guard = ($original_content =~ /#ifndef\s+$guard_name/ || 
                           $original_content =~ /#ifndef\s+__\w+_H/ ||
                           $original_content =~ /#pragma\s+once/);
    
    # Check if file already includes stemmer_exports.h
    my $has_exports_include = ($original_content =~ /#include\s+["<].*stemmer_exports\.h[">]/);
    
    my $modified_content = $original_content;
    
    # Remove any existing STEMMER_EXPORTDEFS definitions
    $modified_content =~ s/#ifndef\s+STEMMER_EXPORTDEFS.*?#endif\s*\n//s;
    
    # Add include for stemmer_exports.h if needed
    if (!$has_exports_include) {
        if ($modified_content =~ /^(.*?)(#include\s+.*$)/sm) {
            # Insert before the first include
            $modified_content = $1 . "#include \"include/stemmer_exports.h\"\n\n" . $2;
        } 
        elsif ($has_header_guard && $modified_content =~ /(#ifndef\s+\w+.*?#define\s+\w+.*?)(\n)/s) {
            # Insert after the header guard
            $modified_content = $1 . $2 . "\n#include \"include/stemmer_exports.h\"\n" . substr($modified_content, length($1) + length($2));
        } 
        else {
            # Add at the top
            $modified_content = "#include \"include/stemmer_exports.h\"\n\n" . $modified_content;
        }
    }
    
    # If there's no header guard, add it
    if (!$has_header_guard) {
        $modified_content = "#ifndef $guard_name\n#define $guard_name\n\n" .
                           $modified_content .
                           "\n\n#endif /* $guard_name */\n";
    }
    
    # Replace extern declarations with extern STEMMER_API
    $modified_content =~ s/extern\s+(?!STEMMER_API)/extern STEMMER_API /g;
    
    # Remove any remaining STEMMER_EXPORTDEFS
    $modified_content =~ s/STEMMER_EXPORTDEFS\s+//g;
    
    # Write the modified content to the output file
    print $out $modified_content;
    close $out;
    
    print "Successfully processed $header_file\n";
}
# Function to process source files and add intptr_t casts to function pointers
sub process_source_file {
    my ($source_file, $output_dir) = @_;
    
    # Skip api.c as it's handled separately
    return if $source_file eq "runtime/api.c";
    
    # Skip utilities.c as it's handled separately
    return if $source_file =~ /\butilities\.c$/;
    
    print "Processing source file: $source_file\n";
    
    # Read the file content
    open my $in, '<', $source_file or die "Cannot open $source_file: $!";
    my $content = do { local $/; <$in> };
    close $in;
    
    my $dest = "$output_dir/$source_file";
    my $dir = dirname($dest);
    make_path($dir) unless -d $dir;
    
    # Check if the file contains among struct initializations
    if ($content =~ /static\s+const\s+struct\s+among/) {
        print "  Adding intptr_t casts to function pointers\n";
        
        # Add explicit casts to function pointers in struct initializations
        # Match the pattern more robustly to ensure we catch all instances
        $content =~ s/(\{\s*\d+\s*,\s*\w+\s*,\s*[-\d]+\s*,\s*[-\d]+\s*,\s*)([a-zA-Z_][a-zA-Z0-9_]*)(\s*\})/$1(intptr_t)$2$3/g;
        
        # Write the modified file
        open my $out, '>', $dest or die "Cannot create $dest: $!";
        print $out $content;
        close $out;
    } else {
        print "  No changes needed, copying directly\n";
        copy($source_file, $dest) or warn "Could not copy $source_file to $dest: $!";
    }
}

1;