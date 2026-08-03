use strict;
use warnings;
use feature 'say';

use File::Copy qw(move);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Time::Piece;

my $home_dir = $ENV{HOME} or die "HOME is not set\n";

# シンボリックリンクのターゲットは必ず絶対パスにする必要があるため、
# スクリプト自身の場所（bootstrap/）から dotfiles ルートを解決し、abs_path で正規化する。
my $script_dir   = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";

# Ghostty はテーマ等を ~/.config/ghostty 配下に追加する可能性があるため、
# config だけをファイル単位でリンクする（親ディレクトリは実体のまま残す）。
my $src_file   = abs_path("$dotfiles_dir/.config/ghostty/config");
my $dest_dir   = "$home_dir/.config/ghostty";
my $dest_file  = "$dest_dir/config";
my $backup_dir = "$dotfiles_dir/back-up/" . localtime->strftime('%Y%m%d_%H%M%S');

if (!$src_file || !-e $src_file) {
    die "[ERROR] Source file does not exist: $dotfiles_dir/.config/ghostty/config\n";
}

say "[INFO] DOTFILES_DIR = $dotfiles_dir";
say "[INFO] SOURCE       = $src_file";
say "[INFO] TARGET       = $dest_file";

# 親ディレクトリ（~/.config/ghostty）を実体として用意する
make_path($dest_dir);

say "------------------------------";

if (-l $dest_file) {
    my $current = readlink($dest_file) // '';
    if ($current eq $src_file) {
        say "[SKIP] $dest_file already links to $src_file";
        say "------------------------------";
        say "[DONE] ghostty setup finished";
        exit 0;
    }
    unlink $dest_file
      or die "Failed to remove old symlink $dest_file: $!\n";
    say "[INFO] Replaced old symlink: $dest_file";
} elsif (-e $dest_file) {
    # 実体ファイルが存在する場合はバックアップへ退避
    make_path($backup_dir);
    my $backup_path = "$backup_dir/config";
    move($dest_file, $backup_path)
      or die "Failed to backup $dest_file -> $backup_path: $!\n";
    say "[INFO] Backup   : $dest_file -> $backup_path";
} else {
    say "[INFO] $dest_file does not exist";
}

symlink $src_file, $dest_file
  or die "Failed to create symlink $dest_file -> $src_file: $!\n";
say "[LINK] $dest_file -> $src_file";

say "------------------------------";
say "[DONE] ghostty setup finished";
