#!/usr/bin/perl
use strict;
use warnings;
use File::Path qw(make_path);
use File::Basename;

# Check command-line arguments
if (@ARGV < 4) {
    die "Usage: $0 <project_name> <output_dir> <vs_version> <source_files> <header_files>\n";
}

my $project_name = $ARGV[0];
my $output_dir = $ARGV[1];
my $vs_version = $ARGV[2];
my @source_files = split(/;/, $ARGV[3]);
my @header_files = split(/;/, $ARGV[4]);

# Make sure output directory exists
make_path($output_dir) unless -d $output_dir;

# Create Visual Studio project file
print "Generating Visual Studio $vs_version project file...\n";

my $project_guid = generate_guid();
my $vcxproj_path = "$output_dir/$project_name.vcxproj";

open my $vcxproj, '>', $vcxproj_path or die "Cannot create $vcxproj_path: $!";

# Generate project header
print $vcxproj <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" ToolsVersion="$vs_version" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Debug|Win32">
      <Configuration>Debug</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug|x64">
      <Configuration>Debug</Configuration>
      <Platform>x64</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug_DLL|Win32">
      <Configuration>Debug_DLL</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Debug_DLL|x64">
      <Configuration>Debug_DLL</Configuration>
      <Platform>x64</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|Win32">
      <Configuration>Release</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|x64">
      <Configuration>Release</Configuration>
      <Platform>x64</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release_DLL|Win32">
      <Configuration>Release_DLL</Configuration>
      <Platform>Win32</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release_DLL|x64">
      <Configuration>Release_DLL</Configuration>
      <Platform>x64</Platform>
    </ProjectConfiguration>
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{$project_guid}</ProjectGuid>
    <Keyword>Win32Proj</Keyword>
    <RootNamespace>$project_name</RootNamespace>
    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
  </PropertyGroup>
  <Import Project="\$(VCTargetsPath)\\Microsoft.Cpp.Default.props" />
  
  <!-- Static Library Configurations -->
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'" Label="Configuration">
    <ConfigurationType>StaticLibrary</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'" Label="Configuration">
    <ConfigurationType>StaticLibrary</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'" Label="Configuration">
    <ConfigurationType>StaticLibrary</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'" Label="Configuration">
    <ConfigurationType>StaticLibrary</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  
  <!-- DLL Configurations -->
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|Win32'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|x64'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>true</UseDebugLibraries>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|Win32'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|x64'" Label="Configuration">
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    <UseDebugLibraries>false</UseDebugLibraries>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  
  <Import Project="\$(VCTargetsPath)\\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
  </ImportGroup>
  
  <!-- Property sheets -->
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|Win32'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|x64'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|Win32'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Label="PropertySheets" Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|x64'">
    <Import Project="\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props" Condition="exists('\$(UserRootDir)\\Microsoft.Cpp.\$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  
  <!-- Global properties -->
  <PropertyGroup Label="UserMacros" />
  
  <!-- Output directories -->
  <PropertyGroup>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">bin\\Debug\\x86\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">bin\\Debug\\x64\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">bin\\Release\\x86\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">bin\\Release\\x64\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|Win32'">bin\\Debug_DLL\\x86\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|x64'">bin\\Debug_DLL\\x64\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|Win32'">bin\\Release_DLL\\x86\\</OutDir>
    <OutDir Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|x64'">bin\\Release_DLL\\x64\\</OutDir>
    
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">obj\\Debug\\x86\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">obj\\Debug\\x64\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">obj\\Release\\x86\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">obj\\Release\\x64\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|Win32'">obj\\Debug_DLL\\x86\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|x64'">obj\\Debug_DLL\\x64\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|Win32'">obj\\Release_DLL\\x86\\</IntDir>
    <IntDir Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|x64'">obj\\Release_DLL\\x64\\</IntDir>
    
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|Win32'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|x64'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|Win32'">$project_name</TargetName>
    <TargetName Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|x64'">$project_name</TargetName>
  </PropertyGroup>

  <!-- Compiler and linker options -->
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|Win32'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>Disabled</Optimization>
      <PreprocessorDefinitions>WIN32;_DEBUG;_LIB;BUILDING_LIBSTEMMER;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
    </Link>
    <Lib>
      <OutputFile>\$(OutDir)\$(TargetName)\$(TargetExt)</OutputFile>
    </Lib>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug|x64'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>Disabled</Optimization>
      <PreprocessorDefinitions>WIN32;_DEBUG;_LIB;BUILDING_LIBSTEMMER;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
    </Link>
    <Lib>
      <OutputFile>\$(OutDir)\$(TargetName)\$(TargetExt)</OutputFile>
    </Lib>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|Win32'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>MaxSpeed</Optimization>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <PreprocessorDefinitions>WIN32;NDEBUG;_LIB;BUILDING_LIBSTEMMER;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <EnableCOMDATFolding>true</EnableCOMDATFolding>
      <OptimizeReferences>true</OptimizeReferences>
    </Link>
    <Lib>
      <OutputFile>\$(OutDir)\$(TargetName)\$(TargetExt)</OutputFile>
    </Lib>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Release|x64'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>MaxSpeed</Optimization>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <PreprocessorDefinitions>WIN32;NDEBUG;_LIB;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <EnableCOMDATFolding>true</EnableCOMDATFolding>
      <OptimizeReferences>true</OptimizeReferences>
    </Link>
    <Lib>
      <OutputFile>\$(OutDir)\$(TargetName)\$(TargetExt)</OutputFile>
    </Lib>
  </ItemDefinitionGroup>
  
  <!-- DLL Configurations -->
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|Win32'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>Disabled</Optimization>
      <PreprocessorDefinitions>WIN32;_DEBUG;_WINDOWS;_USRDLL;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <ModuleDefinitionFile>
      </ModuleDefinitionFile>
    </Link>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Debug_DLL|x64'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>Disabled</Optimization>
      <PreprocessorDefinitions>WIN32;_DEBUG;_WINDOWS;_USRDLL;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <ModuleDefinitionFile>
      </ModuleDefinitionFile>
    </Link>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|Win32'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>MaxSpeed</Optimization>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <PreprocessorDefinitions>WIN32;NDEBUG;_WINDOWS;_USRDLL;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <EnableCOMDATFolding>true</EnableCOMDATFolding>
      <OptimizeReferences>true</OptimizeReferences>
      <ModuleDefinitionFile>
      </ModuleDefinitionFile>
    </Link>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'\$(Configuration)|\$(Platform)'=='Release_DLL|x64'">
    <ClCompile>
      <PrecompiledHeader>NotUsing</PrecompiledHeader>
      <WarningLevel>Level3</WarningLevel>
      <Optimization>MaxSpeed</Optimization>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <PreprocessorDefinitions>WIN32;NDEBUG;_WINDOWS;_USRDLL;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
      <AdditionalIncludeDirectories>include;.;</AdditionalIncludeDirectories>
    </ClCompile>
    <Link>
      <SubSystem>Windows</SubSystem>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <EnableCOMDATFolding>true</EnableCOMDATFolding>
      <OptimizeReferences>true</OptimizeReferences>
      <ModuleDefinitionFile>
      </ModuleDefinitionFile>
    </Link>
  </ItemDefinitionGroup>
EOF

# Add source files to project
print $vcxproj "  <ItemGroup>\n";
foreach my $src_file (@source_files) {
    $src_file =~ s/\//\\/g; # Convert to Windows path separator
    print $vcxproj "    <ClCompile Include=\"$src_file\" />\n";
}
print $vcxproj "  </ItemGroup>\n";

# Add header files to project
print $vcxproj "  <ItemGroup>\n";
foreach my $hdr_file (@header_files) {
    $hdr_file =~ s/\//\\/g; # Convert to Windows path separator
    print $vcxproj "    <ClInclude Include=\"$hdr_file\" />\n";
}
print $vcxproj "  </ItemGroup>\n";

# Close project file
print $vcxproj <<EOF;
  <Import Project="\$(VCTargetsPath)\\Microsoft.Cpp.targets" />
  <ImportGroup Label="ExtensionTargets">
  </ImportGroup>
</Project>
EOF

close $vcxproj;
print "Created $vcxproj_path\n";

# Create Visual Studio filters file
my $filters_path = "$output_dir/$project_name.vcxproj.filters";
open my $filters, '>', $filters_path or die "Cannot create $filters_path: $!";

# Generate filters header
print $filters <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
    <Filter Include="Source Files">
      <UniqueIdentifier>{4FC737F1-C7A5-4376-A066-2A32D752A2FF}</UniqueIdentifier>
      <Extensions>cpp;c;cc;cxx;def;odl;idl;hpj;bat;asm;asmx</Extensions>
    </Filter>
    <Filter Include="Header Files">
      <UniqueIdentifier>{93995380-89BD-4b04-88EB-625FBE52EBFB}</UniqueIdentifier>
      <Extensions>h;hh;hpp;hxx;hm;inl;inc;xsd</Extensions>
    </Filter>
    <Filter Include="Resource Files">
      <UniqueIdentifier>{67DA6AB6-F800-4c08-8B7A-83BB121AAD01}</UniqueIdentifier>
      <Extensions>rc;ico;cur;bmp;dlg;rc2;rct;bin;rgs;gif;jpg;jpeg;jpe;resx;tiff;tif;png;wav;mfcribbon-ms</Extensions>
    </Filter>
  </ItemGroup>
EOF

# Add source file filters
print $filters "  <ItemGroup>\n";
foreach my $src_file (@source_files) {
    $src_file =~ s/\//\\/g; # Convert to Windows path separator
    print $filters "    <ClCompile Include=\"$src_file\">\n";
    print $filters "      <Filter>Source Files</Filter>\n";
    print $filters "    </ClCompile>\n";
}
print $filters "  </ItemGroup>\n";

# Add header file filters
print $filters "  <ItemGroup>\n";
foreach my $hdr_file (@header_files) {
    $hdr_file =~ s/\//\\/g; # Convert to Windows path separator
    print $filters "    <ClInclude Include=\"$hdr_file\">\n";
    print $filters "      <Filter>Header Files</Filter>\n";
    print $filters "    </ClInclude>\n";
}
print $filters "  </ItemGroup>\n";

# Close filters file
print $filters "</Project>\n";
close $filters;
print "Created $filters_path\n";

# Create Visual Studio solution file
my $solution_path = "$output_dir/$project_name.sln";
open my $solution, '>', $solution_path or die "Cannot create $solution_path: $!";

# Generate solution header
my $solution_guid = '{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}';
my $solution_format_version = '12.00';
my $vs_display_version = '14.0'; # Visual Studio 2015

print $solution <<EOF;
Microsoft Visual Studio Solution File, Format Version $solution_format_version
# Visual Studio $vs_display_version
VisualStudioVersion = 14.0.25420.1
MinimumVisualStudioVersion = 10.0.40219.1
Project("$solution_guid") = "$project_name", "$project_name.vcxproj", "{$project_guid}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|x64 = Debug|x64
		Debug|x86 = Debug|x86
		Debug_DLL|x64 = Debug_DLL|x64
		Debug_DLL|x86 = Debug_DLL|x86
		Release|x64 = Release|x64
		Release|x86 = Release|x86
		Release_DLL|x64 = Release_DLL|x64
		Release_DLL|x86 = Release_DLL|x86
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		{$project_guid}.Debug|x64.ActiveCfg = Debug|x64
		{$project_guid}.Debug|x64.Build.0 = Debug|x64
		{$project_guid}.Debug|x86.ActiveCfg = Debug|Win32
		{$project_guid}.Debug|x86.Build.0 = Debug|Win32
		{$project_guid}.Debug_DLL|x64.ActiveCfg = Debug_DLL|x64
		{$project_guid}.Debug_DLL|x64.Build.0 = Debug_DLL|x64
		{$project_guid}.Debug_DLL|x86.ActiveCfg = Debug_DLL|Win32
		{$project_guid}.Debug_DLL|x86.Build.0 = Debug_DLL|Win32
		{$project_guid}.Release|x64.ActiveCfg = Release|x64
		{$project_guid}.Release|x64.Build.0 = Release|x64
		{$project_guid}.Release|x86.ActiveCfg = Release|Win32
		{$project_guid}.Release|x86.Build.0 = Release|Win32
		{$project_guid}.Release_DLL|x64.ActiveCfg = Release_DLL|x64
		{$project_guid}.Release_DLL|x64.Build.0 = Release_DLL|x64
		{$project_guid}.Release_DLL|x86.ActiveCfg = Release_DLL|Win32
		{$project_guid}.Release_DLL|x86.Build.0 = Release_DLL|Win32
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
EndGlobal
EOF

close $solution;
print "Created $solution_path\n";

print "Visual Studio $vs_version project files created successfully.\n";
print "Default configuration set to Release|Win32 (static library).\n";
print "Available configurations:\n";
print "  - Debug|Win32 (static library)\n";
print "  - Debug|x64 (static library)\n";
print "  - Release|Win32 (static library) - default\n";
print "  - Release|x64 (static library)\n";
print "  - Debug_DLL|Win32 (dynamic library)\n";
print "  - Debug_DLL|x64 (dynamic library)\n";
print "  - Release_DLL|Win32 (dynamic library)\n";
print "  - Release_DLL|x64 (dynamic library)\n";
print "PlatformToolset will be selected from the global environment settings.\n";

# Generate a random GUID for the project
sub generate_guid {
    my @chars = ('0'..'9', 'A'..'F');
    my $guid = '';
    
    # Format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
    for my $i (0..31) {
        if ($i == 8 || $i == 12 || $i == 16 || $i == 20) {
            $guid .= '-';
        }
        $guid .= $chars[int(rand(scalar @chars))];
    }
    
    return $guid;
}