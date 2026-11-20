use strict;
use warnings;
use feature 'say';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Copy qw(move);
use File::Path qw(make_path);
use Time::Piece;

if ($^O ne 'darwin' || `uname -m` !~ /^arm64\s*$/) {
    say '[SKIP] Raycast is configured only on Apple Silicon macOS';
    exit 0;
}
my $home_dir = $ENV{HOME} or die "HOME is not set\n";
my $script_dir = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";
my $backup_dir = "$dotfiles_dir/back-up/" . localtime->strftime('%Y%m%d_%H%M%S') . '/raycast';

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

my $app = "$home_dir/.nix-profile/Applications/Raycast.app";
if (-d $app) {
    my $target = "$home_dir/Applications/Raycast.app";
    link_file($app, $target, 'Raycast.app');

    # 起動中のプロセスは profile の切り替え後も古い store path を使い続ける。
    if (system('pgrep', '-x', 'Raycast') == 0) {
        say '[INFO] Restarting Raycast to use the current Nix profile';
        system('osascript', '-e', 'with timeout of 30 seconds', '-e', 'tell application id "com.raycast.macos" to quit', '-e', 'end timeout') == 0
          or die "Failed to quit Raycast; restart it manually.\n";
        for (1 .. 30) {
            last if system('pgrep', '-x', 'Raycast') != 0;
            sleep 1;
        }
        system('pgrep', '-x', 'Raycast') != 0
          or die "Raycast is still running; restart it manually.\n";
        system('open', $target) == 0
          or die "Failed to start Raycast; open $target manually.\n";
        say '[OK] Raycast restarted';
    }
} else {
    say '[INFO] Install dotfiles-tools with Nix, then run make raycast again to link the app.';
}
