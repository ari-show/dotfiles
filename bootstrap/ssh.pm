use strict;
use warnings;
use feature 'say';

use File::Copy qw(copy move);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Time::Piece;

# 1Password の SSH エージェント設定を ~/.ssh に入れる。何度実行しても結果は同じ。
#
#   1. ~/.ssh/config.d/1password.conf を dotfiles へのリンクにする
#   2. ~/.ssh/config に `Include ~/.ssh/config.d/*.conf` が無ければ先頭に 1 行足す
#   3. 以前 ~/.ssh/config に直接書かれた 1Password の `Host *` ブロックを取り除く
#
# ~/.ssh/config にはホスト名など公開したくない情報があるので dotfiles では管理せず、
# 書き換えるのは上の 2 と 3 だけにする。書き換える前に同じディレクトリへバックアップを取る。

my $home_dir = $ENV{HOME} or die "HOME is not set\n";

my $script_dir   = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";

my $src_file  = abs_path("$dotfiles_dir/.config/ssh/1password.conf");
my $ssh_dir   = "$home_dir/.ssh";
my $conf_dir  = "$ssh_dir/config.d";
my $dest_file = "$conf_dir/1password.conf";
my $config    = "$ssh_dir/config";
my $timestamp = localtime->strftime('%Y%m%d_%H%M%S');

my $include_line = 'Include ~/.ssh/config.d/*.conf';

if (!$src_file || !-e $src_file) {
    die "[ERROR] Source file does not exist: $dotfiles_dir/.config/ssh/1password.conf\n";
}

say "[INFO] DOTFILES_DIR = $dotfiles_dir";
say "[INFO] SOURCE       = $src_file";
say "[INFO] TARGET       = $dest_file";
say "[INFO] SSH CONFIG   = $config";
say "------------------------------";

# ssh は ~/.ssh が他人から書き込めると設定を読まないので、新しく作るときは 700 にする。
for my $dir ($ssh_dir, $conf_dir) {
    next if -d $dir;
    make_path($dir, { mode => 0700 });
    chmod 0700, $dir or die "Failed to chmod $dir: $!\n";
    say "[INFO] Created  : $dir";
}

# ---- 1. 専用ファイルのリンク
if (-l $dest_file && (readlink($dest_file) // '') eq $src_file) {
    say "[SKIP] $dest_file already links to $src_file";
} else {
    if (-l $dest_file) {
        unlink $dest_file or die "Failed to remove old symlink $dest_file: $!\n";
        say "[INFO] Replaced old symlink: $dest_file";
    } elsif (-e $dest_file) {
        my $backup = "$dest_file.before-dotfiles.$timestamp";
        move($dest_file, $backup) or die "Failed to backup $dest_file -> $backup: $!\n";
        say "[INFO] Backup   : $dest_file -> $backup";
    }
    symlink $src_file, $dest_file
      or die "Failed to create symlink $dest_file -> $src_file: $!\n";
    say "[LINK] $dest_file -> $src_file";
}

# ---- 2, 3. ~/.ssh/config の確認
if (-l $config) {
    # リンク先は別の仕組みで管理されているはずなので書き換えない。
    say "[SKIP] $config is a symlink; add this line to its target yourself:";
    say "         $include_line";
} elsif (!-e $config) {
    write_config("$include_line\n", 0600);
    say "[ADD]  Created $config with: $include_line";
} else {
    open my $in, '<', $config or die "Failed to read $config: $!\n";
    my @lines = <$in>;
    close $in;
    my $mode = (stat $config)[2] & 07777;

    my ($kept, $removed) = remove_legacy_blocks(@lines);
    my @new = @$kept;

    my $has_include = grep { is_include_line($_) } @new;
    unshift @new, "$include_line\n", "\n" unless $has_include;

    if (!$removed && $has_include) {
        say "[SKIP] $config already has: $include_line";
    } else {
        my $backup = "$config.before-dotfiles.$timestamp";
        copy($config, $backup) or die "Failed to backup $config -> $backup: $!\n";
        chmod $mode, $backup;
        say "[INFO] Backup   : $config -> $backup";

        # 末尾の空行は 1 つにまとめる。
        pop @new while @new && $new[-1] =~ /^\s*$/;
        write_config(join('', @new), $mode);

        say "[ADD]  Added to the top of $config: $include_line" unless $has_include;
        say "[DEL]  Removed $removed duplicated 1Password 'Host *' block(s) from $config" if $removed;
    }
}

say "------------------------------";
say "[DONE] ssh setup finished";

sub is_include_line {
    my ($line) = @_;
    return $line =~ m{^\s*Include\s+"?~/\.ssh/config\.d/\*\.conf"?\s*$}i;
}

sub is_legacy_agent_line {
    my ($line) = @_;
    return $line =~ m{^\s*IdentityAgent\s+"?~/Library/Group Containers/2BUA8C4S2C\.com\.1password/t/agent\.sock"?\s*$}i;
}

# `Host *` の中身が 1Password の IdentityAgent 1 行だけのブロックを取り除く。
# 1Password アプリや手作業で追記されたもので、1password.conf と同じ内容になる。
# ほかの設定が 1 行でも入っているブロックには触らない。
sub remove_legacy_blocks {
    my @lines = @_;

    # Host / Match の行でブロックに区切る。最初のブロックは先頭の共通設定。
    my @blocks = ([]);
    for my $line (@lines) {
        push @blocks, [] if $line =~ /^\s*(?:Host|Match)\b/i;
        push @{ $blocks[-1] }, $line;
    }

    my (@kept, $removed);
    $removed = 0;
    for my $block (@blocks) {
        my ($head, @body) = @$block;
        my @settings = grep { !/^\s*(?:#.*)?$/ } @body;
        if (   defined $head
            && $head =~ /^\s*Host\s+\*\s*$/i
            && @settings == 1
            && is_legacy_agent_line($settings[0])
            && !grep { /^\s*#/ } @body)
        {
            $removed++;
            next;
        }
        push @kept, @$block;
    }
    return (\@kept, $removed);
}

# 一時ファイルに書いてから置き換える。途中で失敗しても元の config は壊れない。
sub write_config {
    my ($content, $mode) = @_;
    my $tmp = "$config.tmp.$$";
    open my $out, '>', $tmp or die "Failed to write $tmp: $!\n";
    chmod $mode, $tmp or die "Failed to chmod $tmp: $!\n";
    print {$out} $content;
    close $out or die "Failed to close $tmp: $!\n";
    rename $tmp, $config or die "Failed to replace $config: $!\n";
}
