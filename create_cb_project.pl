#!/usr/bin/env perl

use strict;
use warnings;
use File::Path qw(make_path);
use Getopt::Long;
use File::Basename;

# Command line arguments
my $output_dir = "";
my $input_file = "";

# Parse command line options
GetOptions(
    "output=s" => \$output_dir,
    "input=s"  => \$input_file
) or die("Error in command line arguments\n");

# Check required parameters
die "Missing output directory parameter (--output)" unless $output_dir;
die "Missing input file parameter (--input)" unless $input_file;

# Ensure the amalgamation directory exists
my $amalgamation_dir = "$output_dir/amalgamation";
make_path($amalgamation_dir) unless -d $amalgamation_dir;

print "Generating C++ Builder project in $amalgamation_dir...\n";

# Create the project file
open my $fh, '>', "$amalgamation_dir/libstemmer.cbproj" 
    or die "Cannot create project file: $!";

# Use a single-quoted here-doc to avoid Perl variable interpretation
# This preserves the MSBuild variables as-is
print $fh <<'EOT';
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <PropertyGroup>
        <ProjectGuid>{D85CD80F-C124-492E-B5F2-79C2EA18F345}</ProjectGuid>
        <ProjectVersion>18.8</ProjectVersion>
        <FrameworkType>None</FrameworkType>
        <Base>True</Base>
        <Config Condition="'$(Config)'==''">Release</Config>
        <Platform Condition="'$(Platform)'==''">Win32</Platform>
        <TargetedPlatforms>3</TargetedPlatforms>
        <AppType>StaticLibrary</AppType>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Config)'=='Base' or '$(Base)'!=''">
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win32' and '$(Base)'=='true') or '$(Base_Win32)'!=''">
        <Base_Win32>true</Base_Win32>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win64' and '$(Base)'=='true') or '$(Base_Win64)'!=''">
        <Base_Win64>true</Base_Win64>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Config)'=='Debug' or '$(Cfg_1)'!=''">
        <Cfg_1>true</Cfg_1>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win32' and '$(Cfg_1)'=='true') or '$(Cfg_1_Win32)'!=''">
        <Cfg_1_Win32>true</Cfg_1_Win32>
        <CfgParent>Cfg_1</CfgParent>
        <Cfg_1>true</Cfg_1>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win64' and '$(Cfg_1)'=='true') or '$(Cfg_1_Win64)'!=''">
        <Cfg_1_Win64>true</Cfg_1_Win64>
        <CfgParent>Cfg_1</CfgParent>
        <Cfg_1>true</Cfg_1>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Config)'=='Release' or '$(Cfg_2)'!=''">
        <Cfg_2>true</Cfg_2>
        <CfgParent>Base</CfgParent>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win32' and '$(Cfg_2)'=='true') or '$(Cfg_2_Win32)'!=''">
        <Cfg_2_Win32>true</Cfg_2_Win32>
        <CfgParent>Cfg_2</CfgParent>
        <Cfg_2>true</Cfg_2>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="('$(Platform)'=='Win64' and '$(Cfg_2)'=='true') or '$(Cfg_2_Win64)'!=''">
        <Cfg_2_Win64>true</Cfg_2_Win64>
        <CfgParent>Cfg_2</CfgParent>
        <Cfg_2>true</Cfg_2>
        <Base>true</Base>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Base)'!=''">
        <DCC_Namespace>System;Xml;Data;Datasnap;Web;Soap;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;$(DCC_Namespace)</DCC_Namespace>
        <BCC_wpar>false</BCC_wpar>
        <PackageImports>rtl.bpi;$(PackageImports)</PackageImports>
        <BPILibOutputDir>.</BPILibOutputDir>
        <IntermediateOutputDir>.\$(Platform)\$(Config)</IntermediateOutputDir>
        <FinalOutputDir>.\$(Platform)\$(Config)</FinalOutputDir>
        <BCC_waus>false</BCC_waus>
        <BCC_OptimizeForSpeed>true</BCC_OptimizeForSpeed>
        <BCC_ExtendedErrorInfo>true</BCC_ExtendedErrorInfo>
        <ILINK_TranslatedLibraryPath>$(BDSLIB)\$(PLATFORM)\release\$(LANGDIR);$(ILINK_TranslatedLibraryPath)</ILINK_TranslatedLibraryPath>
        <ProjectType>CppStaticLibrary</ProjectType>
        <ILINK_LibraryPath>$(BDS)\lib\$(PLATFORM)\$(Config);$(ILINK_LibraryPath)</ILINK_LibraryPath>
        <DCC_CBuilderOutput>JPHNE</DCC_CBuilderOutput>
        <SanitizedProjectName>libstemmer</SanitizedProjectName>
        <_TCHARMapping>wchar_t</_TCHARMapping>
        <BCC_OutputObj>true</BCC_OutputObj>
        <BCC_Defines>BUILDING_LIBSTEMMER;_LIB;$(BCC_Defines)</BCC_Defines>
        <OutputExt>lib</OutputExt>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Base_Win32)'!=''">
        <DCC_Namespace>Winapi;System.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;Bde;$(DCC_Namespace)</DCC_Namespace>
        <VerInfo_Locale>1033</VerInfo_Locale>
        <VerInfo_Keys>CompanyName=;FileDescription=;FileVersion=1.0.0.0;InternalName=;LegalCopyright=;LegalTrademarks=;OriginalFilename=;ProductName=;ProductVersion=1.0.0.0;Comments=</VerInfo_Keys>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Base_Win64)'!=''">
        <DCC_Namespace>Winapi;System.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;$(DCC_Namespace)</DCC_Namespace>
        <VerInfo_Locale>1033</VerInfo_Locale>
        <VerInfo_Keys>CompanyName=;FileDescription=;FileVersion=1.0.0.0;InternalName=;LegalCopyright=;LegalTrademarks=;OriginalFilename=;ProductName=;ProductVersion=1.0.0.0;Comments=</VerInfo_Keys>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Cfg_1)'!=''">
        <BCC_OptimizeForSpeed>false</BCC_OptimizeForSpeed>
        <BCC_DisableOptimizations>true</BCC_DisableOptimizations>
        <DCC_Optimize>false</DCC_Optimize>
        <DCC_DebugInfoInExe>true</DCC_DebugInfoInExe>
        <BCC_InlineFunctionExpansion>false</BCC_InlineFunctionExpansion>
        <BCC_UseRegisterVariables>None</BCC_UseRegisterVariables>
        <DCC_Define>DEBUG</DCC_Define>
        <BCC_DebugLineNumbers>true</BCC_DebugLineNumbers>
        <TASM_DisplaySourceLines>true</TASM_DisplaySourceLines>
        <BCC_StackFrames>true</BCC_StackFrames>
        <ILINK_FullDebugInfo>true</ILINK_FullDebugInfo>
        <TASM_Debugging>Full</TASM_Debugging>
        <BCC_SourceDebuggingOn>true</BCC_SourceDebuggingOn>
        <ILINK_LibraryPath>$(BDSLIB)\$(PLATFORM)\debug;$(ILINK_LibraryPath)</ILINK_LibraryPath>
        <ILINK_TranslatedLibraryPath>$(BDSLIB)\$(PLATFORM)\debug\$(LANGDIR);$(ILINK_TranslatedLibraryPath)</ILINK_TranslatedLibraryPath>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Cfg_1_Win32)'!=''">
        <VerInfo_Locale>1033</VerInfo_Locale>
        <Manifest_File>None</Manifest_File>
        <OutputExt>_d.lib</OutputExt>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Cfg_1_Win64)'!=''">
        <VerInfo_Locale>1033</VerInfo_Locale>
        <Manifest_File>None</Manifest_File>
        <OutputExt>64_d.lib</OutputExt>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Cfg_2)'!=''">
        <TASM_Debugging>None</TASM_Debugging>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Cfg_2_Win32)'!=''">
        <VerInfo_Locale>1033</VerInfo_Locale>
        <Manifest_File>None</Manifest_File>
    </PropertyGroup>
    <PropertyGroup Condition="'$(Cfg_2_Win64)'!=''">
        <VerInfo_Locale>1033</VerInfo_Locale>
        <Manifest_File>None</Manifest_File>
        <OutputExt>64.lib</OutputExt>
    </PropertyGroup>
    <ItemGroup>
EOT

# Add the CppCompile element with the proper input file
print $fh "        <CppCompile Include=\"$input_file\">\n";
print $fh "        </CppCompile>\n";

# Continue with the rest of the static content
print $fh <<'EOT';
        <BuildConfiguration Include="Release">
            <Key>Cfg_2</Key>
            <CfgParent>Base</CfgParent>
        </BuildConfiguration>
        <BuildConfiguration Include="Base">
            <Key>Base</Key>
        </BuildConfiguration>
        <BuildConfiguration Include="Debug">
            <Key>Cfg_1</Key>
            <CfgParent>Base</CfgParent>
        </BuildConfiguration>
    </ItemGroup>
    <ProjectExtensions>
        <Borland.Personality>CPlusPlusBuilder.Personality.12</Borland.Personality>
        <Borland.ProjectType>CppStaticLibrary</Borland.ProjectType>
        <BorlandProject>
            <CPlusPlusBuilder.Personality>
                <ProjectProperties>
                    <ProjectProperties Name="AutoShowDeps">False</ProjectProperties>
                    <ProjectProperties Name="ManagePaths">True</ProjectProperties>
                    <ProjectProperties Name="VerifyPackages">True</ProjectProperties>
                    <ProjectProperties Name="IndexFiles">False</ProjectProperties>
                </ProjectProperties>
                <Excluded_Packages/>
            </CPlusPlusBuilder.Personality>
            <Platforms>
                <Platform value="Win32">True</Platform>
                <Platform value="Win64">True</Platform>
            </Platforms>
        </BorlandProject>
        <ProjectFileVersion>12</ProjectFileVersion>
    </ProjectExtensions>
    <Import Project="$(BDS)\Bin\CodeGear.Cpp.Targets" Condition="Exists('$(BDS)\Bin\CodeGear.Cpp.Targets')"/>
    <Import Project="$(APPDATA)\Embarcadero\$(BDSAPPDATABASEDIR)\$(PRODUCTVERSION)\UserTools.proj" Condition="Exists('$(APPDATA)\Embarcadero\$(BDSAPPDATABASEDIR)\$(PRODUCTVERSION)\UserTools.proj')"/>
</Project>
EOT
close $fh;

# Create a group project file
open my $grp_fh, '>', "$amalgamation_dir/libstemmer.groupproj" 
    or die "Cannot create group project file: $!";

# Use a single-quoted here-doc for the group project file
print $grp_fh <<'EOT';
<?xml version="1.0" encoding="utf-8"?>
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <PropertyGroup>
        <ProjectGuid>{23A5ACB2-C58D-4F36-85D7-010999F15871}</ProjectGuid>
    </PropertyGroup>
    <ItemGroup>
        <Projects Include="libstemmer.cbproj">
            <Dependencies/>
        </Projects>
    </ItemGroup>
    <ProjectExtensions>
        <Borland.Personality>Default.Personality.12</Borland.Personality>
        <Borland.ProjectType/>
        <BorlandProject>
            <Default.Personality/>
        </BorlandProject>
    </ProjectExtensions>
    <Target Name="libstemmer">
        <MSBuild Projects="libstemmer.cbproj"/>
    </Target>
    <Target Name="libstemmer:Clean">
        <MSBuild Projects="libstemmer.cbproj" Targets="Clean"/>
    </Target>
    <Target Name="libstemmer:Make">
        <MSBuild Projects="libstemmer.cbproj" Targets="Make"/>
    </Target>
    <Target Name="Build">
        <CallTarget Targets="libstemmer"/>
    </Target>
    <Target Name="Clean">
        <CallTarget Targets="libstemmer:Clean"/>
    </Target>
    <Target Name="Make">
        <CallTarget Targets="libstemmer:Make"/>
    </Target>
    <Import Project="$(BDS)\Bin\CodeGear.Group.Targets" Condition="Exists('$(BDS)\Bin\CodeGear.Group.Targets')"/>
</Project>
EOT
close $grp_fh;

print "C++ Builder project files generated successfully:\n";
print "  - $amalgamation_dir/libstemmer.cbproj\n";
print "  - $amalgamation_dir/libstemmer.groupproj\n";

exit 0;