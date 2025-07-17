#!/usr/bin/perl
use strict;
use warnings;
use File::Path qw(make_path);
use File::Basename;
use File::Copy;
use FindBin;
use lib $FindBin::Bin;
use libstemmer_vs_helpers;
use POSIX qw(strftime);

# Configuration
my $project_name = "libstemmer";
my $output_dir = "vs_build";
my $mkinc_file = "mkinc.mak";

# Create output directory
make_path($output_dir) unless -d $output_dir;

# Create include directory for our custom headers
my $include_dir = "$output_dir/include";
make_path($include_dir) unless -d $include_dir;

# Generate export definitions and build config headers
create_stemmer_exports_h($output_dir);
create_build_config_h($output_dir);

# Parse mkinc.mak file
print "Parsing $mkinc_file to extract source and header files...\n";
open my $mkinc_fh, '<', $mkinc_file or die "Cannot open $mkinc_file: $!";
my $content = do { local $/; <$mkinc_fh> };
close $mkinc_fh;

my @snowball_sources;
my @snowball_headers;

# Extract snowball_sources
if ($content =~ /snowball_sources=\s*(.*?)(?=\n\w+|$)/s) {
    my $sources_block = $1;
    $sources_block =~ s/\\$//mg;  # Remove trailing backslashes
    @snowball_sources = $sources_block =~ /\s*(\S+)\s*/g;
}

# Extract snowball_headers
if ($content =~ /snowball_headers=\s*(.*?)(?=\n\w+|$)/s) {
    my $headers_block = $1;
    $headers_block =~ s/\\$//mg;  # Remove trailing backslashes
    @snowball_headers = $headers_block =~ /\s*(\S+)\s*/g;
}

print "Found " . scalar(@snowball_sources) . " source files and " . scalar(@snowball_headers) . " header files.\n";

# Create directory structure in output directory
my %dirs_to_create;
foreach my $file (@snowball_sources, @snowball_headers) {
    my $dir = dirname($file);
    $dirs_to_create{$dir} = 1;
}

foreach my $dir (keys %dirs_to_create) {
    make_path("$output_dir/$dir") unless -d "$output_dir/$dir";
}

# Process all header files
print "Adding export declarations to header files...\n";
foreach my $header (@snowball_headers) {
    if ($header =~ /\.h$/) {
        process_header_file($header, $output_dir);
    } else {
        # Just copy non-header files
        my $dest = "$output_dir/$header";
        print "  Copying $header to $dest\n";
        copy($header, $dest) or warn "Could not copy $header to $dest: $!";
    }
}

# Check if api.h exists in various locations and process it
print "Looking for api.h...\n";
foreach my $api_h_path ("api.h", "runtime/api.h", "include/api.h") {
    if (-f $api_h_path) {
        print "Found api.h at $api_h_path\n";
        process_api_h($api_h_path, $output_dir);
        last;
    }
}

# Check if libstemmer.h exists in various locations and process it
print "Looking for libstemmer.h...\n";
my $found_libstemmer_h = 0;
foreach my $libstemmer_h_path ("libstemmer.h", "include/libstemmer.h", "include/libstemmer/libstemmer.h", "src/libstemmer.h") {
    if (-f $libstemmer_h_path) {
        print "Found libstemmer.h at $libstemmer_h_path\n";
        process_libstemmer_h($libstemmer_h_path, $output_dir);
        $found_libstemmer_h = 1;
        last;
    }
}
if (!$found_libstemmer_h) {
    print "WARNING: Could not find libstemmer.h in standard locations. API functions will not be exported.\n";
}

# Process source files
print "Processing source files...\n";
foreach my $source (@snowball_sources) {
    # Process runtime/api.c specially
    if ($source eq "runtime/api.c") {
        process_api_c($source, $output_dir);
    } 
    # Check for utilities.c (with any path)
    elsif ($source =~ /\butilities\.c$/) {
        process_utilities_c($source, $output_dir);
    }
    else {
        process_source_file($source, $output_dir);
    }
}

# Ensure utilities.c is processed even if not listed in mkinc.mak
print "Checking for additional utilities.c file...\n";
process_utilities_c("utilities.c", $output_dir);

# Convert to Windows paths for the VS project files
my @win_sources = map { my $s = $_; $s =~ s/\//\\/g; $s } @snowball_sources;
my @win_headers = map { my $s = $_; $s =~ s/\//\\/g; $s } @snowball_headers;

# Add our custom headers to the list
push @win_headers, "include\\stemmer_exports.h";
push @win_headers, "include\\build_config.h";

# Call the helper script to create the VS project files
my $vs_version = "14.0"; # Visual Studio 2015
print "Calling helper script to create Visual Studio project files...\n";

# Build the command to call the helper script
my $command = "perl create_vs_project.pl \"$project_name\" \"$output_dir\" \"$vs_version\" ";

# Add sources
$command .= "\"" . join(";", @win_sources) . "\" ";

# Add headers
$command .= "\"" . join(";", @win_headers) . "\"";

print "Executing: $command\n";
system($command) == 0 or die "Failed to create VS project files: $?";

# Get current date in YYYY-MM-DD HH:MM:SS format
my $current_date = strftime("%Y-%m-%d %H:%M:%S", localtime);

print "Done!\n";
print "Visual Studio solution has been created in the $output_dir directory.\n";
print "Open $output_dir/$project_name.sln to build the library.\n";
print "The library will be compiled with /MT flag (static runtime library) for static builds.\n";
print "The DLL will be built with /MD flag and export only the main API functions.\n";
print "Function declarations and implementations have been modified for Visual Studio compatibility.\n";
print "Last update: $current_date\n";