use strict;
use warnings;
use feature 'say';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Spec;

my $home = $ENV{HOME} or die "HOME is not set\n";
my $root = abs_path($ENV{DOTFILES} // dirname(abs_path(__FILE__)) . '/..')
  or die "Failed to resolve dotfiles directory\n";
my $source = abs_path("$root/.config/lazyvim") or die "LazyVim config is missing\n";
my $config = $ENV{XDG_CONFIG_HOME} // '';
$config = "$home/.config" unless File::Spec->file_name_is_absolute($config);
my $target = "$config/lazyvim";
make_path($config);
if (-l $target && (readlink($target) // '') eq $source) {
    say "[SKIP] $target already links to $source";
} elsif (-e $target || -l $target) {
    die "[ERROR] $target already exists; leave it in place and resolve it manually\n";
} else {
    symlink $source, $target or die "Failed to link $target: $!\n";
    say "[LINK] $target -> $source";
}
