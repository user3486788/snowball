#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Basename;
use File::Path qw(make_path);
use File::Copy qw(copy);
use Digest::MD5 qw(md5_hex);
use Getopt::Long;
use File::Spec;

print "Current Date and Time (UTC): 2025-07-17 08:58:53\n";
print "Current User's Login: user3486788\n";
print "File name: amalgamate.pl\n";
print "Language: perl\n\n";

# Хеши файлов чтобы избежать дублирование
my %file_hashes;

# Словарь для хранения глобальных переменных и их переименований
my %global_vars;
my %global_var_renames;

# Словарь для отслеживания уже определенных функций
my %defined_functions;

# Параметры командной строки
my $output_name = "libstemmer_amalgamation";
my $skip_duplicates = 1; # By default, skip duplicates
GetOptions(
    "name=s" => \$output_name,
    "skip-duplicates!" => \$skip_duplicates,
    "help" => sub {
        print "Использование: $0 [опции]\n";
        print "Опции:\n";
        print "  --name=NAME          Задает базовое имя для результирующих файлов (по умолчанию: libstemmer_amalgamation)\n";
        print "  --skip-duplicates    Пропускать дублирующиеся файлы по содержимому (по умолчанию: включено)\n";
        print "  --no-skip-duplicates Не пропускать дублирующиеся файлы\n";
        print "  --help               Показывает это сообщение\n";
        exit 0;
    }
);

# Convert path separators to platform-specific
sub normalize_path {
    my $path = shift;
    return File::Spec->canonpath($path);
}

# Директории
my $src_dir = normalize_path('./src_c');
my $runtime_dir = normalize_path('./runtime');
my $libstemmer_dir = normalize_path('./libstemmer');
my $include_dir = normalize_path('./include');
my $output_dir = normalize_path('./amalgamation');
my $snowball_dir = normalize_path('./');  # Current directory is often the snowball directory

print "Source directory: $src_dir\n";
print "Runtime directory: $runtime_dir\n";
print "Libstemmer directory: $libstemmer_dir\n";
print "Include directory: $include_dir\n";
print "Output directory: $output_dir\n";
print "Output files base name: $output_name\n";
print "Skip duplicates: " . ($skip_duplicates ? "yes" : "no") . "\n";

# Get paths for mkmodules.pl arguments
my $modules_description = normalize_path("$libstemmer_dir/modules.txt");
my $source_list = normalize_path("$libstemmer_dir/libstemmer_sources");
my $mkinc_mak = normalize_path("./mkinc.mak");

# Only run mkmodules.pl if mkinc.mak doesn't exist
if (!-f $mkinc_mak) {
    # Run mkmodules.pl to generate mkinc.mak with the list of required files
    my $mkmodules_path = normalize_path("$libstemmer_dir/mkmodules.pl");
    if (-f $mkmodules_path && -f $modules_description) {
        print "mkinc.mak not found. Running $mkmodules_path to generate it...\n";
        my $cmd = "perl $mkmodules_path $mkinc_mak $src_dir $modules_description $source_list";
        print "Command: $cmd\n";
        system($cmd);
        if ($? == 0) {
            print "Successfully generated mkinc.mak\n";
        } else {
            print "WARNING: Failed to run mkmodules.pl, error code: $?\n";
        }
    } else {
        print "WARNING: Could not find $mkmodules_path or $modules_description\n";
    }
} else {
    print "Found existing mkinc.mak, using it...\n";
}

# Parse mkinc.mak to get the source file lists
my @snowball_sources = ();
my @snowball_headers = ();

if (-f $mkinc_mak) {
    print "Parsing mkinc.mak to get source file lists...\n";
    open(my $mkinc, "<", $mkinc_mak) or die "Cannot open mkinc.mak: $!";
    my $in_sources = 0;
    my $in_headers = 0;
    
    while (my $line = <$mkinc>) {
        chomp $line;
        
        if ($line =~ /^snowball_sources\s*=\s*\\$/) {
            $in_sources = 1;
            $in_headers = 0;
            next;
        } elsif ($line =~ /^snowball_headers\s*=\s*\\$/) {
            $in_sources = 0;
            $in_headers = 1;
            next;
        }
        
        if ($in_sources) {
            if ($line =~ /^\s+(\S+)\s*\\?$/) {
                push @snowball_sources, normalize_path($1);
            } else {
                $in_sources = 0;
            }
        } elsif ($in_headers) {
            if ($line =~ /^\s+(\S+)\s*\\?$/) {
                push @snowball_headers, normalize_path($1);
            } else {
                $in_headers = 0;
            }
        }
    }
    
    close($mkinc);
    
    print "Found " . scalar(@snowball_sources) . " source files and " . scalar(@snowball_headers) . " header files in mkinc.mak\n";
} else {
    print "WARNING: mkinc.mak not found, falling back to file system search\n";
}

# Critical files that must be included
my @critical_files = (
    normalize_path("$runtime_dir/api.c"),
    normalize_path("$runtime_dir/utilities.c"),
    normalize_path("$libstemmer_dir/libstemmer.c")
);

# If we didn't get source files from mkinc.mak, try to find them in the filesystem
if (@snowball_sources == 0) {
    print "Looking for source files in the filesystem...\n";
    
    # Проверка директорий
    unless (-d $src_dir) {
        if (-d $runtime_dir) {
            $src_dir = $runtime_dir;
            print "Using runtime as source directory: $src_dir\n";
        } elsif (-d "../runtime") {
            $src_dir = normalize_path("../runtime");
            print "Using parent runtime as source directory: $src_dir\n";
        } else {
            print "WARNING: Source directory $src_dir not found, will search current directory\n";
        }
    }
    
    # Find C files
    foreach my $dir ($src_dir, $runtime_dir, $libstemmer_dir, ".") {
        if (-d $dir) {
            push @snowball_sources, find_files($dir, 'c');
        }
    }

    # Find header files
    unless (-d $include_dir) {
        mkdir $include_dir;
        print "Created include directory: $include_dir\n";
    }
    
    @snowball_headers = find_files($include_dir, 'h');
    push @snowball_headers, find_files($src_dir, 'h');
}

# Add critical files directly if they exist and aren't already included
foreach my $critical_file (@critical_files) {
    if (-f $critical_file && !grep { $_ eq $critical_file } @snowball_sources) {
        print "Adding critical file directly: $critical_file\n";
        push @snowball_sources, $critical_file;
    }
}

die "ERROR: No source files found!\n" if @snowball_sources == 0;

print "Using " . scalar(@snowball_sources) . " source files and " . scalar(@snowball_headers) . " header files.\n";

# Print the list of source files for debugging
print "Source files:\n";
foreach my $file (sort @snowball_sources) {
    print "  $file\n";
}

# Create output directory if needed
make_path($output_dir) unless -d $output_dir;

# Имена выходных файлов
my $amalgamation_c = "$output_dir/${output_name}.c";
my $amalgamation_h = "$output_dir/${output_name}.h";

# Открываем файлы
open(my $c_out, ">", $amalgamation_c) or die "Cannot open $amalgamation_c: $!";
open(my $h_out, ">", $amalgamation_h) or die "Cannot open $amalgamation_h: $!";

# Запись заголовков
print $h_out "/* ${output_name}.h - Snowball stemming library combined header */\n";
print $h_out "#ifndef ${output_name}_H\n";
print $h_out "#define ${output_name}_H\n\n";
print $h_out "#include <stdio.h>\n";
print $h_out "#include <stdlib.h>\n";
print $h_out "#include <string.h>\n";
print $h_out "#include <limits.h>\n\n";

# Базовые типы и структуры
print $h_out "/* Basic types and structures */\n";
print $h_out "typedef unsigned char symbol;\n\n";

print $h_out "struct SN_env {\n";
print $h_out "    symbol * p;\n";
print $h_out "    int c;\n";
print $h_out "    int l;\n";
print $h_out "    int lb;\n";
print $h_out "    int bra;\n";
print $h_out "    int ket;\n";
print $h_out "    symbol * * S;\n";
print $h_out "    int * I;\n";
print $h_out "    unsigned char * B;\n";
print $h_out "};\n\n";

print $h_out "struct among {\n";
print $h_out "    const symbol * s;\n";
print $h_out "    int s_size;\n";
print $h_out "    int substring_i;\n";
print $h_out "    int result;\n";
print $h_out "    int (* function)(struct SN_env *);\n";
print $h_out "};\n\n";

# Adding required structure definitions for libstemmer
print $h_out "/* Stemmer structures */\n";
print $h_out "typedef enum {\n";
print $h_out "    ENC_UTF_8, /* UTF-8 */\n";
print $h_out "    ENC_ISO_8859_1, /* ISO Latin 1 */\n";
print $h_out "    ENC_ISO_8859_2, /* ISO Latin 2 */\n";
print $h_out "    ENC_KOI8_R,     /* KOI8-R */\n";
print $h_out "    ENC_UNKNOWN     /* Unknown */\n";
print $h_out "} stemmer_encoding_t;\n\n";

print $h_out "struct stemmer_modules {\n";
print $h_out "    const char * name;\n";
print $h_out "    stemmer_encoding_t enc;\n";
print $h_out "    struct SN_env * (*create)(void);\n";
print $h_out "    void (*close)(struct SN_env *);\n";
print $h_out "    int (*stem)(struct SN_env *);\n";
print $h_out "};\n\n";

print $h_out "struct sb_stemmer {\n";
print $h_out "    struct SN_env * env;\n";
print $h_out "    struct stemmer_modules * modinfo;\n";
print $h_out "};\n\n";

# Добавляем прототипы функций API
print $h_out "/* API function prototypes */\n";
print $h_out "extern struct SN_env * SN_create_env(int starter_size, int max_size);\n";
print $h_out "extern void SN_close_env(struct SN_env * z, int keep_windows);\n";
print $h_out "extern int SN_set_current(struct SN_env * z, int size, const symbol * s);\n\n";

# Определяем функции для работы с группами символов и строками
print $h_out "/* For stemmer internal use only */\n";
print $h_out "extern int skip_utf8(const symbol * p, int c, int lb, int l, int n);\n";
print $h_out "extern int skip_utf8_2args(const symbol * p, int c);\n";
print $h_out "extern int skip_utf8_3args(const symbol * p, int c, int lb);\n";
print $h_out "extern int skip_utf8_4args(const symbol * p, int c, int lb, int l);\n";
print $h_out "extern int skip_b_utf8(const symbol * p, int c, int lb, int l, int n);\n";
print $h_out "extern int skip_b_utf8_2args(const symbol * p, int c);\n";
print $h_out "extern int skip_b_utf8_3args(const symbol * p, int c, int lb);\n";
print $h_out "extern int skip_b_utf8_4args(const symbol * p, int c, int lb, int l);\n";
print $h_out "extern int len_utf8(const symbol * p);\n";

print $h_out "extern int find_among(struct SN_env * z, const struct among * v, int v_size);\n";
print $h_out "extern int find_among_b(struct SN_env * z, const struct among * v, int v_size);\n";

print $h_out "extern int in_grouping(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";
print $h_out "extern int in_grouping_b(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";
print $h_out "extern int out_grouping(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";
print $h_out "extern int out_grouping_b(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";

print $h_out "extern int in_grouping_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";
print $h_out "extern int in_grouping_b_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";
print $h_out "extern int out_grouping_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";
print $h_out "extern int out_grouping_b_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";

# Updated to match the 5-parameter pattern
print $h_out "extern int in_grouping_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";
print $h_out "extern int in_grouping_b_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";
print $h_out "extern int out_grouping_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";
print $h_out "extern int out_grouping_b_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat);\n";

# Add 4-parameter versions
print $h_out "extern int in_grouping_U_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";
print $h_out "extern int in_grouping_b_U_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";
print $h_out "extern int out_grouping_U_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";
print $h_out "extern int out_grouping_b_U_4args(struct SN_env * z, const unsigned char * s, int min, int max);\n";

print $h_out "extern int eq_s(struct SN_env * z, int s_size, const symbol * s);\n";
print $h_out "extern int eq_s_b(struct SN_env * z, int s_size, const symbol * s);\n";
print $h_out "extern int eq_v(struct SN_env * z, const symbol * p);\n";
print $h_out "extern int eq_v_b(struct SN_env * z, const symbol * p);\n";

print $h_out "extern int slice_del(struct SN_env * z);\n";
print $h_out "extern int slice_from_s(struct SN_env * z, int s_size, const symbol * s);\n";
print $h_out "extern symbol * slice_to(struct SN_env * z, symbol * p);\n";
print $h_out "extern int insert_v(struct SN_env * z, int bra, int ket, const symbol * p);\n";
print $h_out "extern int insert_s(struct SN_env * z, int bra, int ket, int s_size, const symbol * s);\n";

print $h_out "extern symbol * create_s(void);\n";
print $h_out "extern void lose_s(symbol * p);\n";
print $h_out "extern int replace_s(struct SN_env * z, int bra, int ket, int s_size, const symbol * s, int function_call);\n";

# Stemmer-related functions
print $h_out "extern struct sb_stemmer * sb_stemmer_new(const char * algorithm, const char * charenc);\n";
print $h_out "extern void sb_stemmer_delete(struct sb_stemmer * stemmer);\n";
print $h_out "extern const char ** sb_stemmer_list(void);\n";
print $h_out "extern int sb_stemmer_stem(struct sb_stemmer * stemmer, const unsigned char * word, int size);\n";
print $h_out "extern const unsigned char * sb_stemmer_get_result(struct sb_stemmer * stemmer);\n";
print $h_out "extern int sb_stemmer_get_result_length(struct sb_stemmer * stemmer);\n";
print $h_out "extern stemmer_encoding_t sb_getenc(const char * charenc);\n";

print $h_out "\n";

# Функция для поиска файлов
sub find_files {
    my ($dir, $ext) = @_;
    my @result;
    
    return () unless -d $dir;
    
    opendir(my $dh, $dir) or return ();
    my @entries = grep { !/^\.\.?$/ } readdir($dh);
    closedir($dh);
    
    foreach my $entry (@entries) {
        my $path = normalize_path("$dir/$entry");
        if (-d $path) {
            push @result, find_files($path, $ext);
        } elsif ($path =~ /\.$ext$/i) {
            push @result, $path;
        }
    }
    
    return @result;
}

# Функция для получения языка и кодировки из имени файла
sub get_lang_encoding {
    my $file = shift;
    my $basename = basename($file);
    
    if ($basename =~ /^stem_(.+?)_(.+?)\.c$/) {
        my ($lang, $encoding) = ($1, $2);
        $encoding =~ s/-/_/g;
        return ($lang, $encoding);
    }
    
    return (undef, undef);
}

# Добавляем объявления stemmers к заголовочному файлу
print $h_out "/* Stemmer function prototypes */\n";
foreach my $c_file (@snowball_sources) {
    if ($c_file =~ /stem_(.+?)_(.+?)\.c$/) {
        my ($lang, $encoding) = ($1, $2);
        $encoding =~ s/-/_/g;
        print $h_out "extern struct SN_env * ${lang}_${encoding}_create_env(void);\n";
        print $h_out "extern void ${lang}_${encoding}_close_env(struct SN_env * z);\n";
        print $h_out "extern int ${lang}_${encoding}_stem(struct SN_env * z);\n";
    }
}

print $h_out "\n#endif /* ${output_name}_H */\n";

# Начинаем запись в C-файл
print $c_out "/* ${output_name}.c - Snowball stemming library amalgamated source */\n\n";
print $c_out "#include \"${output_name}.h\"\n\n";
print $c_out "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n";

# Добавляем макросы для совместимости между разными типами
print $c_out "/* Helper macros for structure initialization */\n";
print $c_out "#define NULL_SYMBOL ((const symbol *)0)\n";
print $c_out "#define NULL_FUNCTION ((int (*)(struct SN_env *))0)\n\n";

# Internal structures and defines needed for utilities.c and libstemmer.c
print $c_out "/* Additional internal structures and defines */\n";
print $c_out "#ifndef HEAD\n";
print $c_out "#define HEAD 2*sizeof(int)\n";
print $c_out "#endif\n\n";

print $c_out "#ifndef SIZE\n";
print $c_out "#define SIZE(p) ((int *)(p))[-1]\n";
print $c_out "#endif\n\n";

print $c_out "#ifndef CAPACITY\n";
print $c_out "#define CAPACITY(p) ((int *)(p))[-2]\n";
print $c_out "#endif\n\n";

print $c_out "#ifndef SET_SIZE\n";
print $c_out "#define SET_SIZE(p, n) ((int *)(p))[-1] = n\n";
print $c_out "#endif\n\n";

# Categorize files
my @utilities_files = grep { basename($_) =~ /utilities|api/ } @snowball_sources;
my @stem_files = grep { basename($_) =~ /^stem_/ } @snowball_sources;
my @other_files = grep { basename($_) !~ /^stem_|utilities|api|libstemmer/ } @snowball_sources;
my @libstemmer_files = grep { basename($_) =~ /libstemmer/ } @snowball_sources;

# Print categorized files for debugging
print "Utility files (" . scalar(@utilities_files) . "):\n";
foreach my $file (sort @utilities_files) {
    print "  $file\n";
}

print "Libstemmer files (" . scalar(@libstemmer_files) . "):\n";
foreach my $file (sort @libstemmer_files) {
    print "  $file\n";
}

print "Other files (" . scalar(@other_files) . "):\n";
foreach my $file (sort @other_files) {
    print "  $file\n";
}

print "Stem files (" . scalar(@stem_files) . "):\n";
foreach my $file (sort @stem_files) {
    print "  $file\n";
}

# Словарь идентификаторов для каждого языка
my %language_identifiers;

# Функция для извлечения определений глобальных переменных
sub extract_global_variables {
    my ($file, $content) = @_;
    my ($lang, $encoding) = get_lang_encoding($file);
    my $prefix = $lang && $encoding ? "${lang}_${encoding}_" : "";
    
    # Ищем глобальные переменные (g_*)
    while ($content =~ /static\s+const\s+(?:unsigned\s+)?(?:char|symbol)\s+(g_\w+)\s*\[/g) {
        my $var_name = $1;
        my $pos = pos($content) - length($var_name) - 1;
        my $declaration_start = $pos;
        
        # Сканируем назад для нахождения начала объявления
        while ($declaration_start > 0 && substr($content, $declaration_start - 1, 1) ne "\n" && 
               substr($content, $declaration_start - 1, 1) ne ";") {
            $declaration_start--;
        }
        
        # Ищем конец объявления (до точки с запятой)
        my $declaration_end = pos($content);
        my $brace_level = 0;
        my $in_string = 0;
        
        while ($declaration_end < length($content)) {
            my $char = substr($content, $declaration_end, 1);
            
            if ($char eq '"' && substr($content, $declaration_end - 1, 1) ne "\\") {
                $in_string = !$in_string;
            } elsif ($char eq "{" && !$in_string) {
                $brace_level++;
            } elsif ($char eq "}" && !$in_string) {
                $brace_level--;
            } elsif ($char eq ";" && !$in_string && $brace_level == 0) {
                $declaration_end++;
                last;
            }
            
            $declaration_end++;
        }
        
        # Извлекаем полное объявление
        my $declaration = substr($content, $declaration_start, $declaration_end - $declaration_start);
        my $renamed_var = "${prefix}${var_name}";
        my $renamed_declaration = $declaration;
        $renamed_declaration =~ s/\b$var_name\b/$renamed_var/g;
        
        # Сохраняем объявление
        $global_vars{$var_name}{$file} = {
            'definition' => $declaration,
            'renamed' => $renamed_var,
            'renamed_definition' => $renamed_declaration
        };
        
        # Записываем отображение для замены
        $global_var_renames{$file}{$var_name} = $renamed_var;
        
        print "  Found global variable $var_name in $file (renamed to $renamed_var)\n";
    }
}

# Первый проход: сканируем все файлы и собираем глобальные переменные
print "First pass: collecting global variables...\n";
foreach my $file (@stem_files) {
    open(my $in, "<", $file) or next;
    my $content = do { local $/; <$in> };
    close($in);
    
    # Извлекаем глобальные переменные
    extract_global_variables($file, $content);
}

# Выводим собранные глобальные переменные с уникальными именами
print $c_out "/* Global character groupings used by stemmers */\n";
my %emitted_globals;

foreach my $var_name (sort keys %global_vars) {
    foreach my $file (sort keys %{$global_vars{$var_name}}) {
        my $info = $global_vars{$var_name}{$file};
        my $renamed_var = $info->{'renamed'};
        
        # Выводим только если эта переменная еще не была выведена
        if (!$emitted_globals{$renamed_var}) {
            print $c_out $info->{'renamed_definition'} . "\n";
            $emitted_globals{$renamed_var} = 1;
        }
    }
}
print $c_out "\n";

# First pass through all files to collect function definitions
print "Scanning files for function definitions...\n";
foreach my $file (@snowball_sources) {
    if (-f $file) {
        open(my $in, "<", $file) or next;
        my $content = do { local $/; <$in> };
        close($in);
        
        # Extract function definitions
        while ($content =~ /\b(\w+)\s*\([^)]*\)\s*\{/g) {
            my $func_name = $1;
            $defined_functions{$func_name} = $file;
            print "  Found function definition: $func_name in $file\n" if $func_name =~ /grouping|skip_utf8|slice|insert|create_s|lose_s|replace_s/;
        }
    }
}

# Define some helper functions only if we don't find them in utilities files
if (!$defined_functions{'skip_utf8_2args'}) {
    # Создаем вспомогательные функции для skip_utf8 с разным числом аргументов
    print $c_out "/* Helper functions for skip_utf8 with various parameter counts */\n";
    
    print $c_out "int skip_utf8_2args(const symbol *p, int c) {\n";
    print $c_out "    return skip_utf8(p, c, 0, INT_MAX, 1);\n";
    print $c_out "}\n";
    print $c_out "\n";
    print $c_out "int skip_utf8_3args(const symbol *p, int c, int lb) {\n";
    print $c_out "    return skip_utf8(p, c, lb, INT_MAX, 1);\n";
    print $c_out "}\n";
    print $c_out "\n";
    print $c_out "int skip_utf8_4args(const symbol *p, int c, int lb, int l) {\n";
    print $c_out "    return skip_utf8(p, c, lb, l, 1);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'skip_utf8_2args'} = 'generated';
    $defined_functions{'skip_utf8_3args'} = 'generated';
    $defined_functions{'skip_utf8_4args'} = 'generated';
}

if (!$defined_functions{'skip_b_utf8_2args'}) {
    # Also add helper functions for skip_b_utf8
    print $c_out "/* Helper functions for skip_b_utf8 with various parameter counts */\n";
    print $c_out "int skip_b_utf8_2args(const symbol *p, int c) {\n";
    print $c_out "    return skip_b_utf8(p, c, 0, INT_MAX, 1);\n";
    print $c_out "}\n";
    print $c_out "\n";
    print $c_out "int skip_b_utf8_3args(const symbol *p, int c, int lb) {\n";
    print $c_out "    return skip_b_utf8(p, c, lb, INT_MAX, 1);\n";
    print $c_out "}\n";
    print $c_out "\n";
    print $c_out "int skip_b_utf8_4args(const symbol *p, int c, int lb, int l) {\n";
    print $c_out "    return skip_b_utf8(p, c, lb, l, 1);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'skip_b_utf8_2args'} = 'generated';
    $defined_functions{'skip_b_utf8_3args'} = 'generated';
    $defined_functions{'skip_b_utf8_4args'} = 'generated';
}

if (!$defined_functions{'in_grouping_4args'}) {
    # Add helper functions for *_grouping functions with 4 parameters
    print $c_out "/* Helper functions for grouping with 4 parameters */\n";
    print $c_out "int in_grouping_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return in_grouping(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    print $c_out "int in_grouping_b_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return in_grouping_b(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    print $c_out "int out_grouping_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return out_grouping(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    print $c_out "int out_grouping_b_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return out_grouping_b(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'in_grouping_4args'} = 'generated';
    $defined_functions{'in_grouping_b_4args'} = 'generated';
    $defined_functions{'out_grouping_4args'} = 'generated';
    $defined_functions{'out_grouping_b_4args'} = 'generated';
}

if (!$defined_functions{'in_grouping_U_4args'}) {
    # Add helper functions for Unicode grouping functions
    print $c_out "/* Helper functions for Unicode grouping with 4 parameters */\n";
    print $c_out "int in_grouping_U_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return in_grouping_U(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    print $c_out "int in_grouping_b_U_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return in_grouping_b_U(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    print $c_out "int out_grouping_U_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return out_grouping_U(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    print $c_out "int out_grouping_b_U_4args(struct SN_env * z, const unsigned char * s, int min, int max) {\n";
    print $c_out "    return out_grouping_b_U(z, s, min, max, 0);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'in_grouping_U_4args'} = 'generated';
    $defined_functions{'in_grouping_b_U_4args'} = 'generated';
    $defined_functions{'out_grouping_U_4args'} = 'generated';
    $defined_functions{'out_grouping_b_U_4args'} = 'generated';
}

if (!$defined_functions{'in_grouping_U'}) {
    # Add stubs for Unicode grouping functions (if not found in utilities)
    print $c_out "/* Unicode grouping functions */\n";
    print $c_out "int in_grouping_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat) {\n";
    print $c_out "    return in_grouping(z, s, min, max, repeat);\n";
    print $c_out "}\n\n";
    
    print $c_out "int in_grouping_b_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat) {\n";
    print $c_out "    return in_grouping_b(z, s, min, max, repeat);\n";
    print $c_out "}\n\n";
    
    print $c_out "int out_grouping_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat) {\n";
    print $c_out "    return out_grouping(z, s, min, max, repeat);\n";
    print $c_out "}\n\n";
    
    print $c_out "int out_grouping_b_U(struct SN_env * z, const unsigned char * s, int min, int max, int repeat) {\n";
    print $c_out "    return out_grouping_b(z, s, min, max, repeat);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'in_grouping_U'} = 'generated';
    $defined_functions{'in_grouping_b_U'} = 'generated';
    $defined_functions{'out_grouping_U'} = 'generated';
    $defined_functions{'out_grouping_b_U'} = 'generated';
}

# Check if we need to provide stub implementations for other required functions
if (!$defined_functions{'slice_del'}) {
    print $c_out "/* String operations - stub implementations */\n";
    print $c_out "int slice_del(struct SN_env * z) {\n";
    print $c_out "    if (z->bra >= 0 && z->ket >= z->bra) {\n";
    print $c_out "        memmove(z->p + z->bra, z->p + z->ket, (z->l - z->ket) * sizeof(symbol));\n";
    print $c_out "        z->l -= z->ket - z->bra;\n";
    print $c_out "        z->ket = z->bra;\n";
    print $c_out "        return 0;\n";
    print $c_out "    }\n";
    print $c_out "    return -1;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'slice_del'} = 'generated';
}

if (!$defined_functions{'slice_from_s'}) {
    print $c_out "int slice_from_s(struct SN_env * z, int s_size, const symbol * s) {\n";
    print $c_out "    if (z->bra >= 0 && z->ket >= z->bra) {\n";
    print $c_out "        int new_size = z->l - (z->ket - z->bra) + s_size;\n";
    print $c_out "        symbol *new_p = malloc(new_size * sizeof(symbol));\n";
    print $c_out "        if (!new_p) return -1;\n";
    print $c_out "        memcpy(new_p, z->p, z->bra * sizeof(symbol));\n";
    print $c_out "        memcpy(new_p + z->bra, s, s_size * sizeof(symbol));\n";
    print $c_out "        memcpy(new_p + z->bra + s_size, z->p + z->ket, (z->l - z->ket) * sizeof(symbol));\n";
    print $c_out "        free(z->p); z->p = new_p;\n";
    print $c_out "        z->l = new_size;\n";
    print $c_out "        z->ket = z->bra + s_size;\n";
    print $c_out "        return 0;\n";
    print $c_out "    }\n";
    print $c_out "    return -1;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'slice_from_s'} = 'generated';
}

if (!$defined_functions{'slice_to'}) {
    print $c_out "symbol * slice_to(struct SN_env * z, symbol * p) {\n";
    print $c_out "    if (z->bra >= 0 && z->ket >= z->bra) {\n";
    print $c_out "        int len = z->ket - z->bra;\n";
    print $c_out "        if (p != NULL) free(p);\n";
    print $c_out "        p = malloc((len + 1) * sizeof(symbol));\n";
    print $c_out "        if (p) {\n";
    print $c_out "            memmove(p, z->p + z->bra, len * sizeof(symbol));\n";
    print $c_out "            p[len] = 0;\n";
    print $c_out "        }\n";
    print $c_out "        return p;\n";
    print $c_out "    }\n";
    print $c_out "    return NULL;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'slice_to'} = 'generated';
}

if (!$defined_functions{'insert_s'}) {
    print $c_out "int insert_s(struct SN_env * z, int bra, int ket, int s_size, const symbol * s) {\n";
    print $c_out "    if (bra <= ket && bra >= 0 && ket <= z->l) {\n";
    print $c_out "        int new_size = z->l - (ket - bra) + s_size;\n";
    print $c_out "        symbol *new_p = malloc(new_size * sizeof(symbol));\n";
    print $c_out "        if (!new_p) return -1;\n";
    print $c_out "        memcpy(new_p, z->p, bra * sizeof(symbol));\n";
    print $c_out "        memcpy(new_p + bra, s, s_size * sizeof(symbol));\n";
    print $c_out "        memcpy(new_p + bra + s_size, z->p + ket, (z->l - ket) * sizeof(symbol));\n";
    print $c_out "        free(z->p); z->p = new_p;\n";
    print $c_out "        z->l = new_size;\n";
    print $c_out "        z->ket = bra + s_size;\n";
    print $c_out "        if (z->bra > ket) z->bra += s_size - (ket - bra);\n";
    print $c_out "        else if (z->bra > bra) z->bra = bra + s_size;\n";
    print $c_out "        return 0;\n";
    print $c_out "    }\n";
    print $c_out "    return -1;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'insert_s'} = 'generated';
}

if (!$defined_functions{'insert_v'}) {
    print $c_out "int insert_v(struct SN_env * z, int bra, int ket, const symbol * v) {\n";
    print $c_out "    int len = 0;\n";
    print $c_out "    while (v[len] != 0) len++;\n";
    print $c_out "    return insert_s(z, bra, ket, len, v);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'insert_v'} = 'generated';
}

if (!$defined_functions{'len_utf8'}) {
    print $c_out "int len_utf8(const symbol * p) {\n";
    print $c_out "    int len = 0;\n";
    print $c_out "    if (!p) return 0;\n";
    print $c_out "    while (*p++) len++;\n";
    print $c_out "    return len;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'len_utf8'} = 'generated';
}

if (!$defined_functions{'create_s'}) {
    print $c_out "symbol * create_s(void) {\n";
    print $c_out "    symbol * p = malloc(HEAD);\n";
    print $c_out "    if (p) {\n";
    print $c_out "        CAPACITY(p) = 0;\n";
    print $c_out "        SET_SIZE(p, 0);\n";
    print $c_out "    }\n";
    print $c_out "    return p;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'create_s'} = 'generated';
}

if (!$defined_functions{'lose_s'}) {
    print $c_out "void lose_s(symbol * p) {\n";
    print $c_out "    if (p) free((int *)p - 2);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'lose_s'} = 'generated';
}

if (!$defined_functions{'skip_b_utf8'} && !$defined_functions{'skip_b_utf8'}) {
    print $c_out "int skip_b_utf8(const symbol * p, int c, int lb, int l, int n) {\n";
    print $c_out "    return skip_utf8(p, c, lb, l, -n);\n";
    print $c_out "}\n\n";
    
    $defined_functions{'skip_b_utf8'} = 'generated';
}

if (!$defined_functions{'replace_s'}) {
    print $c_out "int replace_s(struct SN_env * z, int bra, int ket, int s_size, const symbol * s, int function_call) {\n";
    print $c_out "    int adjustment = s_size - (ket - bra);\n";
    print $c_out "    int ret;\n";
    print $c_out "    if (!function_call) {\n";
    print $c_out "        z->bra = bra;\n";
    print $c_out "        z->ket = ket;\n";
    print $c_out "    }\n";
    print $c_out "    ret = insert_s(z, bra, ket, s_size, s);\n";
    print $c_out "    if (!function_call) z->ket += adjustment;\n";
    print $c_out "    return ret;\n";
    print $c_out "}\n\n";
    
    $defined_functions{'replace_s'} = 'generated';
}

# Собираем все идентификаторы из всех файлов стеммеров
print "Analyzing stemmer files...\n";
foreach my $file (@stem_files) {
    my ($lang, $encoding) = get_lang_encoding($file);
    next unless $lang && $encoding;
    
    open(my $in, "<", $file) or next;
    my $content = do { local $/; <$in> };
    close($in);
    
    # Удаляем включения заголовочных файлов
    $content =~ s/#\s*include\s+["<][^">]+[">]//g;
    
    # Идентификаторы символьных массивов
    while ($content =~ /static\s+const\s+symbol\s+(\w+)/g) {
        my $id = $1;
        next if $id =~ /^g_/; # Пропускаем глобальные переменные
        $language_identifiers{$lang}{$encoding}{$id} = "${lang}_${encoding}_$id";
    }
    
    # Идентификаторы массивов
    while ($content =~ /static\s+const\s+(?:int|char|unsigned)\s+(\w+)(?:\s*\[\s*\d+\s*\])?/g) {
        my $id = $1;
        next if $id =~ /^g_/; # Пропускаем глобальные переменные
        $language_identifiers{$lang}{$encoding}{$id} = "${lang}_${encoding}_$id";
    }
    
    # Идентификаторы структур among
    while ($content =~ /static\s+const\s+struct\s+among\s+(\w+)/g) {
        my $id = $1;
        $language_identifiers{$lang}{$encoding}{$id} = "${lang}_${encoding}_$id";
    }
    
    # Идентификаторы функций
    while ($content =~ /static\s+(int|void)\s+(\w+)\s*\(/g) {
        my $id = $2;
        $language_identifiers{$lang}{$encoding}{$id} = "${lang}_${encoding}_$id";
    }
    
    # Идентификаторы r_ функций
    while ($content =~ /static\s+int\s+(r_\w+)/g) {
        my $id = $1;
        $language_identifiers{$lang}{$encoding}{$id} = "${lang}_${encoding}_$id";
    }
    
    # Идентификаторы s_N и s_N_M
    while ($content =~ /\b(s_\d+(?:_\d+)?)\b/g) {
        my $id = $1;
        $language_identifiers{$lang}{$encoding}{$id} = "${lang}_${encoding}_$id";
    }
}

# Generate the algorithm_names and modules arrays for libstemmer.c
print $c_out "/* Algorithm names for libstemmer */\n";
print $c_out "static const char * algorithm_names[] = {\n";
foreach my $file (sort @stem_files) {
    if ($file =~ /stem_(.+?)_(.+?)\.c$/) {
        my $lang = $1;
        print $c_out "    \"$lang\",\n";
    }
}
print $c_out "    NULL\n";
print $c_out "};\n\n";

print $c_out "/* Stemmer modules for supported languages */\n";
print $c_out "static const struct stemmer_modules modules[] = {\n";
foreach my $file (sort @stem_files) {
    if ($file =~ /stem_(.+?)_(.+?)\.c$/) {
        my ($lang, $encoding) = ($1, $2);
        $encoding =~ s/-/_/g;
        print $c_out "    {\"$lang\", ENC_UTF_8, ${lang}_${encoding}_create_env, ${lang}_${encoding}_close_env, ${lang}_${encoding}_stem},\n";
    }
}
print $c_out "    {NULL, ENC_UNKNOWN, NULL, NULL, NULL}\n";
print $c_out "};\n\n";

# Process files in the order they appear in mkinc.mak
print "Processing source files in order from mkinc.mak...\n";

# First, process the critical files specifically to make sure they're included
print "Processing critical files first...\n";
foreach my $file (@critical_files) {
    if (-f $file) {
        process_critical_file($file);
    }
}

# Обрабатываем файлы утилит первыми (if any left)
print "Processing utility files...\n";
foreach my $file (@utilities_files) {
    # Skip files that were already processed as critical
    next if grep { $_ eq $file } @critical_files;
    process_utility_file($file);
}

# Обрабатываем остальные не-stemmer файлы
print "Processing other base files...\n";
foreach my $file (@other_files) {
    process_utility_file($file);
}

# Обрабатываем файлы стеммеров
print "Processing stemmer files...\n";
foreach my $file (@stem_files) {
    process_stemmer_file($file);
}

# Обрабатываем файлы libstemmer последними (if any left)
print "Processing libstemmer files...\n";
foreach my $file (@libstemmer_files) {
    # Skip files that were already processed as critical
    next if grep { $_ eq $file } @critical_files;
    process_libstemmer_file($file);
}

# Завершаем C-файл
print $c_out "#ifdef __cplusplus\n}\n#endif\n";

# Закрываем файлы
close($c_out);
close($h_out);

# Создаем промежуточный файл с заменой всех проблемных вызовов skip_utf8
print "Fixing all skip_utf8 and skip_b_utf8 calls and struct among initializers...\n";
my $temp_file = "$output_dir/temp_file.c";

open(my $in, "<", $amalgamation_c) or die "Cannot open $amalgamation_c for reading: $!";
open(my $out, ">", $temp_file) or die "Cannot open $temp_file for writing: $!";

# Заменяем все проблемные вызовы skip_utf8 с разным количеством аргументов
while (my $line = <$in>) {
    # Сначала исправляем вызовы с 4 аргументами
    if ($line =~ /\bskip_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bskip_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/skip_utf8_4args($1, $2, $3, $4)/g;
    }
    # Затем исправляем вызовы с 3 аргументами
    elsif ($line =~ /\bskip_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bskip_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/skip_utf8_3args($1, $2, $3)/g;
    }
    # Наконец, исправляем вызовы с 2 аргументами
    elsif ($line =~ /\bskip_utf8\s*\(\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bskip_utf8\s*\(\s*([^,]+),\s*([^,\)]+)\s*\)/skip_utf8_2args($1, $2)/g;
    }

    # Fix skip_b_utf8 calls with different argument counts
    if ($line =~ /\bskip_b_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bskip_b_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/skip_b_utf8_4args($1, $2, $3, $4)/g;
    }
    elsif ($line =~ /\bskip_b_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bskip_b_utf8\s*\(\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/skip_b_utf8_3args($1, $2, $3)/g;
    }
    elsif ($line =~ /\bskip_b_utf8\s*\(\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bskip_b_utf8\s*\(\s*([^,]+),\s*([^,\)]+)\s*\)/skip_b_utf8_2args($1, $2)/g;
    }

    # Fix in_grouping and out_grouping functions with only 4 arguments
    if ($line =~ /\bin_grouping\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bin_grouping\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/in_grouping_4args($1, $2, $3, $4)/g;
    }
    if ($line =~ /\bout_grouping\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bout_grouping\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/out_grouping_4args($1, $2, $3, $4)/g;
    }
    if ($line =~ /\bin_grouping_b\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bin_grouping_b\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/in_grouping_b_4args($1, $2, $3, $4)/g;
    }
    if ($line =~ /\bout_grouping_b\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bout_grouping_b\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/out_grouping_b_4args($1, $2, $3, $4)/g;
    }

    # Fix in_grouping_U and out_grouping_U functions with 4 arguments
    if ($line =~ /\bin_grouping_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bin_grouping_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/in_grouping_U_4args($1, $2, $3, $4)/g;
    }
    if ($line =~ /\bout_grouping_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bout_grouping_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/out_grouping_U_4args($1, $2, $3, $4)/g;
    }
    if ($line =~ /\bin_grouping_b_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bin_grouping_b_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/in_grouping_b_U_4args($1, $2, $3, $4)/g;
    }
    if ($line =~ /\bout_grouping_b_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/) {
        $line =~ s/\bout_grouping_b_U\s*\(\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\s*\)/out_grouping_b_U_4args($1, $2, $3, $4)/g;
    }

    # Исправляем структуры among для правильной инициализации типов
    $line =~ s/\{(\s*0\s*,)/\{NULL_SYMBOL,/g;
    $line =~ s/(\s*,\s*0\s*\})$/, NULL_FUNCTION\}/g;
    
        # FIX FOR REVERSED AMONG FIELDS - Swap first two fields in struct among initializers
    # Pattern: { <integer>, <identifier>, ... } → { <identifier>, <integer>, ... }
    if ($line =~ /{\s*(\d+)\s*,\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*,/) {
        $line =~ s/{\s*(\d+)\s*,\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*,/{ $2, $1, /g;
    }
    
    print $out $line;
}

close($in);
close($out);

# Копируем исправленный файл обратно
if (copy($temp_file, $amalgamation_c)) {
    print "Successfully copied fixed file\n";
} else {
    die "Failed to copy fixed file: $!";
}
unlink($temp_file);

print "Amalgamation files created successfully:\n";
print "  $amalgamation_c\n";
print "  $amalgamation_h\n";
print "Global variables collected: " . scalar(keys %global_vars) . "\n";
print "Renamed global variables: " . scalar(keys %emitted_globals) . "\n";
print "Current Date and Time (UTC): 2025-07-17 09:03:44\n";
print "Current User's Login: user3486788\n";

# Function to process critical files (api.c, utilities.c, libstemmer.c)
sub process_critical_file {
    my $file = shift;
    print "  Processing CRITICAL file: $file\n";
    
    open(my $in, "<", $file) or do {
        print "    ERROR: Could not open critical file: $file - $!\n";
        return;
    };
    my $content = do { local $/; <$in> };
    close($in);
    
    # Skip duplicate check for critical files
    print "    Including critical file content: $file\n";
    
    # Удаляем включения заголовочных файлов
    $content =~ s/#\s*include\s+["<][^">]+[">]//g;
    
    # Fix libstemmer.c to properly declare required structs
    my $basename = basename($file);
    if ($basename eq "libstemmer.c") {
        # If the file doesn't already have proper struct definitions, make sure they are added
        if ($content !~ /\bstruct\s+stemmer_modules\b/) {
            # Replace declarations with references to the ones we added to the header
            $content =~ s/typedef enum \{[^}]+\} stemmer_encoding_t;/\/\* stemmer_encoding_t is defined in header \*\//g;
            $content =~ s/struct stemmer_modules[^;]+;/\/\* stemmer_modules is defined in header \*\//g;
            $content =~ s/struct sb_stemmer\s+\{[^}]+\};/\/\* sb_stemmer is defined in header \*\//g;
        }
    }
    
    # Track function definitions to avoid duplicates
    my @func_defs = $content =~ /\b(\w+)\s*\([^)]*\)\s*\{/g;
    foreach my $func (@func_defs) {
        $defined_functions{$func} = 1;
        print "    Found critical function definition: $func\n" if $func =~ /grouping|skip_utf8|slice|insert|create_s|lose_s|replace_s/;
    }
    
    print $c_out "/* CRITICAL File: $file */\n$content\n\n";
}

# Функция для обработки файла утилит
sub process_utility_file {
    my $file = shift;
    print "  Processing file: $file\n";
    
    open(my $in, "<", $file) or do {
        print "    ERROR: Could not open file: $file - $!\n";
        return;
    };
    my $content = do { local $/; <$in> };
    close($in);
    
    # Track function definitions to avoid duplicates later
    my @func_defs = $content =~ /\b(\w+)\s*\([^)]*\)\s*\{/g;
    foreach my $func (@func_defs) {
        $defined_functions{$func} = 1;
        print "    Found function definition: $func\n" if $func =~ /grouping|skip_utf8|slice|insert|create_s|lose_s|replace_s/;
    }
    
    # Вычисляем хеш для избежания дубликатов
    my $hash = md5_hex($content);
    if ($skip_duplicates && exists $file_hashes{$hash}) {
        print "    Skipping duplicate content from $file (use --no-skip-duplicates to include it)\n";
        return;
    }
    $file_hashes{$hash} = 1;
    
    # Check for critical files and print special messages
    my $basename = basename($file);
    if ($basename eq "api.c" || $basename eq "utilities.c" || $basename eq "libstemmer.c") {
        print "    Including critical file: $file\n";
    }
    
    # Удаляем включения заголовочных файлов
    $content =~ s/#\s*include\s+["<][^">]+[">]//g;
    
    print $c_out "/* File: $file */\n$content\n\n";
}

# Функция для обработки файла stemmers
sub process_stemmer_file {
    my $file = shift;
    my ($lang, $encoding) = get_lang_encoding($file);
    return unless $lang && $encoding;
    
    print "  Processing stemmer: $file (lang: $lang, encoding: $encoding)\n";
    
    open(my $in, "<", $file) or do {
        print "    ERROR: Could not open file: $file - $!\n";
        return;
    };
    my $content = do { local $/; <$in> };
    close($in);
    
    # Удаляем включения заголовочных файлов
    $content =~ s/#\s*include\s+["<][^">]+[">]//g;
    
    # Исправляем структуры among для правильной инициализации типов
    $content =~ s/\{\s*0\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*0\s*\}/{NULL_SYMBOL, $1, $2, $3, NULL_FUNCTION}/g;
    
    # Исправляем swap struct among fields if they are in the wrong order
    $content =~ s/{\s*(\d+)\s*,\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*,/{ $2, $1, /g;
    
    # Удаляем объявления глобальных переменных
    foreach my $var_name (keys %{$global_var_renames{$file}}) {
        my $var_info = $global_vars{$var_name}{$file};
        $content =~ s/\Q$var_info->{'definition'}\E//s;
    }
    
    # Заменяем использования глобальных переменных на переименованные версии
    foreach my $var_name (keys %{$global_var_renames{$file}}) {
        my $renamed = $global_var_renames{$file}{$var_name};
        # Заменяем только идентификаторы, а не части других слов
        $content =~ s/\b$var_name\b/$renamed/g;
    }
    
    # Переименовываем все идентификаторы, кроме локальных переменных и параметров функций
    my $id_map = $language_identifiers{$lang}{$encoding};
    foreach my $id (sort { length($b) <=> length($a) } keys %$id_map) {
        my $prefixed = $id_map->{$id};
        
        # Исключаем глобальные идентификаторы (g_*)
        next if $id =~ /^g_/;
        
        # Исключаем общие имена переменных и параметры функций
        next if $id =~ /^(i|j|k|c|ch|tmp|len|size|limit|cursor|p|bra|ket|l|lb|among_var|ret|z|v_\d+)$/;
        
        # Замена объявлений структур и массивов (не затрагивая локальные переменные функций)
        $content =~ s/(static\s+const\s+symbol\s+)$id(\s*\[\s*\d+\s*\])/$1$prefixed$2/g;
        $content =~ s/(static\s+const\s+struct\s+among\s+)$id(\s*\[\s*\d+\s*\])/$1$prefixed$2/g;
        $content =~ s/(static\s+(?:int|void)\s+)$id(\s*\()/$1$prefixed$2/g;
        
        # Замена обращений к функциям и массивам
        $content =~ s/\b$id\s*\(/$prefixed(/g;  # Вызовы функций
        $content =~ s/\b$id\s*\[/$prefixed\[/g; # Доступ к массивам
        
        # Осторожная замена остальных идентификаторов, только если они являются самостоятельными токенами
        # и не являются частью объявлений локальных переменных
        $content =~ s/\b$id\b(?!\s*[\(\[]|_)(?!\s*=)(?!.*?(?:int|char|symbol|struct)\s+)/$prefixed/g;
    }
    
    # Корректируем обращения к публичным функциям
    $content =~ s/\bstem\s*\(/${lang}_${encoding}_stem(/g;
    $content =~ s/\bcreate_env\s*\(\s*\)/${lang}_${encoding}_create_env()/g;
    $content =~ s/\bclose_env\s*\(/${lang}_${encoding}_close_env(/g;
    
    print $c_out "/* File: $file */\n$content\n\n";
}

# Функция для обработки файлов libstemmer
sub process_libstemmer_file {
    my $file = shift;
    print "  Processing libstemmer file: $file\n";
    
    open(my $in, "<", $file) or do {
        print "    ERROR: Could not open file: $file - $!\n";
        return;
    };
    my $content = do { local $/; <$in> };
    close($in);
    
    # Track function definitions to avoid duplicates
    my @func_defs = $content =~ /\b(\w+)\s*\([^)]*\)\s*\{/g;
    foreach my $func (@func_defs) {
        $defined_functions{$func} = 1;
        print "    Found libstemmer function definition: $func\n" if $func =~ /sb_/;
    }
    
    # Вычисляем хеш для избежания дубликатов
    my $hash = md5_hex($content);
    if ($skip_duplicates && exists $file_hashes{$hash}) {
        print "    Skipping duplicate content from $file (use --no-skip-duplicates to include it)\n";
        return;
    }
    $file_hashes{$hash} = 1;
    
    # Check for critical files and print special messages
    my $basename = basename($file);
    if ($basename eq "libstemmer.c") {
        print "    Including critical file: $file\n";
        
        # Special handling for libstemmer.c
        if ($content =~ /struct stemmer_modules/) {
            # Remove struct definitions that are already in the header
            $content =~ s/typedef enum \{[^}]+\} stemmer_encoding_t;/\/\* stemmer_encoding_t is defined in header \*\//g;
            $content =~ s/struct stemmer_modules[^;]+;/\/\* stemmer_modules is defined in header \*\//g;
            $content =~ s/struct sb_stemmer\s+\{[^}]+\};/\/\* sb_stemmer is defined in header \*\//g;
        }
    }
    
    # Удаляем включения заголовочных файлов
    $content =~ s/#\s*include\s+["<][^">]+[">]//g;
    
    # Корректируем обращения к функциям языков
    foreach my $lang (keys %language_identifiers) {
        foreach my $encoding (keys %{$language_identifiers{$lang}}) {
            $content =~ s/\b${lang}_${encoding}_stem\s*\(/${lang}_${encoding}_stem(/g;
            $content =~ s/\b${lang}_${encoding}_create_env\s*\(/${lang}_${encoding}_create_env(/g;
            $content =~ s/\b${lang}_${encoding}_close_env\s*\(/${lang}_${encoding}_close_env(/g;
        }
    }
    
    # For libstemmer.c, fix any missing implementations of required functions
    if ($basename eq "libstemmer.c") {
        if ($content !~ /\bsb_stemmer_get_result\b/) {
            print $c_out "/* Missing stemmer result functions */\n";
            print $c_out "const unsigned char * sb_stemmer_get_result(struct sb_stemmer * stemmer) {\n";
            print $c_out "    return stemmer->env->p;\n";
            print $c_out "}\n\n";
            
            print $c_out "int sb_stemmer_get_result_length(struct sb_stemmer * stemmer) {\n";
            print $c_out "    return stemmer->env->l;\n";
            print $c_out "}\n\n";
        }
        
        if ($content !~ /\bsb_getenc\b/) {
            print $c_out "/* Missing encoding function */\n";
            print $c_out "stemmer_encoding_t sb_getenc(const char * charenc) {\n";
            print $c_out "    if (charenc == NULL) return ENC_UTF_8;\n";
            print $c_out "    if (strcmp(charenc, \"UTF_8\") == 0) return ENC_UTF_8;\n";
            print $c_out "    if (strcmp(charenc, \"ISO_8859_1\") == 0) return ENC_ISO_8859_1;\n";
            print $c_out "    if (strcmp(charenc, \"ISO_8859_2\") == 0) return ENC_ISO_8859_2;\n";
            print $c_out "    if (strcmp(charenc, \"KOI8_R\") == 0) return ENC_KOI8_R;\n";
            print $c_out "    return ENC_UNKNOWN;\n";
            print $c_out "}\n\n";
        }
    }
    
    print $c_out "/* File: $file */\n$content\n\n";
}