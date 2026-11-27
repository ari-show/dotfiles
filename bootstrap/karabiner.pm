use strict;
use warnings;
use feature 'say';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Copy qw(move);
use File::Path qw(make_path);
use Time::Piece;

if ($^O ne 'darwin' || `uname -m` !~ /^arm64\s*$/) {
    say '[SKIP] Karabiner-Elements is configured only on Apple Silicon macOS';
    exit 0;
}
my $home_dir = $ENV{HOME} or die "HOME is not set\n";
my $script_dir = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";
my $backup_dir = "$dotfiles_dir/back-up/" . localtime->strftime('%Y%m%d_%H%M%S') . '/karabiner';

# 公式の署名者（Fumihiko Takayama）の Team ID。
my $team_id = 'G43BCU2T37';
my $installed_app = '/Applications/Karabiner-Elements.app';

sub link_file {
    my ($source, $target, $backup_name) = @_;
    make_path(dirname($target));
    if (-l $target && (readlink($target) // '') eq $source) {
        say "[SKIP] $target already links to $source";
        return;
    }
    if (-e $target || -l $target) {
        make_path($backup_dir);
        my $backup = "$backup_dir/$backup_name";
        die "Backup already exists: $backup\n" if -e $backup || -l $backup;
        move($target, $backup) or die "Failed to backup $target: $!\n";
        say "[BACKUP] $target -> $backup";
    }
    symlink($source, $target) or die "Failed to link $target: $!\n";
    say "[LINK] $target -> $source";
}

sub version_parts {
    my ($version) = @_;
    $version =~ /^\d+(?:\.\d+)*$/ or die "Unsupported version: $version\n";
    return split /\./, $version;
}

sub compare_versions {
    my @a = version_parts($_[0]);
    my @b = version_parts($_[1]);
    while (@a || @b) {
        my $cmp = (shift(@a) // 0) <=> (shift(@b) // 0);
        return $cmp if $cmp;
    }
    return 0;
}

sub installed_version {
    my $plist = "$installed_app/Contents/Info.plist";
    return undef unless -f $plist;
    my $version = `/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '$plist' 2>/dev/null`;
    chomp $version;
    return $version eq '' ? undef : $version;
}

# GUI で変更した設定もこのリポジトリに直接書き込まれるよう、ディレクトリごとリンクする。
# （karabiner.json 単体のリンクは、GUI の保存時に通常のファイルへ置き換わることがある）
my $config = abs_path("$dotfiles_dir/.config/karabiner")
  or die "Karabiner config not found\n";
link_file($config, "$home_dir/.config/karabiner", 'karabiner');

my $share = "$home_dir/.nix-profile/share/karabiner-elements";
my $pkg = "$share/Karabiner-Elements.pkg";
unless (-f $pkg && -f "$share/version") {
    say '[INFO] Install dotfiles-tools with Nix, then run make karabiner again to install the app.';
    exit 0;
}
open my $fh, '<', "$share/version" or die "Failed to read $share/version: $!\n";
chomp(my $pinned = <$fh> // '');
close $fh;

my $current = installed_version();
if (defined $current) {
    my $cmp = compare_versions($current, $pinned);
    if ($cmp == 0) {
        say "[SKIP] Karabiner-Elements $current is already installed";
        exit 0;
    }
    if ($cmp > 0) {
        say "[WARN] Installed Karabiner-Elements $current is newer than the pinned $pinned; not downgrading.";
        say '[WARN] Update nix/karabiner-source.json to match, or uninstall it first to downgrade.';
        exit 0;
    }
}

# 公式の Developer ID で署名・公証された pkg だけを入れる。
my $signature = `pkgutil --check-signature '$pkg' 2>&1`;
$? == 0 && $signature =~ /\(\Q$team_id\E\)/ && $signature =~ /trusted by the Apple notary service/
  or die "Unexpected signature on $pkg:\n$signature";

say '[INFO] Installing Karabiner-Elements ' . $pinned . (defined $current ? " (from $current)" : '') . ' (needs sudo)';
system('sudo', 'installer', '-pkg', $pkg, '-target', '/') == 0
  or die "Failed to install Karabiner-Elements\n";
say "[OK] Karabiner-Elements $pinned installed";
say '[INFO] On first install, approve the driver and Input Monitoring in System Settings as Karabiner-Elements asks.'
  unless defined $current;
