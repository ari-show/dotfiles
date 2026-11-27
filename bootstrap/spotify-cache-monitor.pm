use strict;
use warnings;
use feature 'say';
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Path qw(make_path);

# Spotify キャッシュ容量の週次通知 (LaunchAgent) を有効化 / 停止する。
#
#   perl bootstrap/spotify-cache-monitor.pm           # 有効化（再実行すると plist を入れ直す）
#   perl bootstrap/spotify-cache-monitor.pm uninstall # 停止して plist を削除
#
# リポジトリの plist は ~/dotfiles に置く前提で書かれているので、
# コピー時にこのリポジトリの実際の場所へ書き換える。
# LAUNCHCTL を指定すると launchctl の代わりにそのコマンドを呼ぶ（検証用）。

my $label = 'com.dotfiles.spotify-cache-monitor';
my $mode  = shift // 'install';
die "Usage: perl $0 [install|uninstall]\n" if $mode !~ /^(?:install|uninstall)$/;

if ($^O ne 'darwin') {
    say '[SKIP] The Spotify cache monitor is available only on macOS';
    exit 0;
}

my $home_dir = $ENV{HOME} or die "HOME is not set\n";
my $script_dir = dirname(abs_path(__FILE__));
my $dotfiles_dir = abs_path($ENV{DOTFILES} // "$script_dir/..")
  or die "Failed to resolve dotfiles directory\n";
my $launchctl = $ENV{LAUNCHCTL} // '/bin/launchctl';
my $domain = "gui/$<";
my $target = "$home_dir/Library/LaunchAgents/$label.plist";

sub bootout {
    # 未登録なら失敗するが、その場合は何もしなくてよい。
    if (system("$launchctl print $domain/$label >/dev/null 2>&1") == 0) {
        system($launchctl, 'bootout', "$domain/$label") == 0
          or die "Failed to stop $label\n";
        say "[STOP] $label";
    }
}

if ($mode eq 'uninstall') {
    bootout();
    if (-e $target || -l $target) {
        unlink($target) or die "Failed to remove $target: $!\n";
        say "[REMOVE] $target";
    }
    say '[OK] Spotify cache monitor disabled';
    exit 0;
}

my $script = "$dotfiles_dir/scripts/spotify-cache-monitor";
-x $script or die "Script is not executable: $script\n";
# plist では bash -c の二重引用符内に埋め込むので、展開される文字を含む場所は扱わない。
$dotfiles_dir !~ /["\$`\\]/
  or die "Unsupported characters in dotfiles path: $dotfiles_dir\n";

my $source = "$dotfiles_dir/.config/launchd/$label.plist";
open my $in, '<', $source or die "Failed to read $source: $!\n";
my $plist = do { local $/; <$in> };
close $in;

(my $xml_dir = $dotfiles_dir) =~ s/&/&amp;/g;
$xml_dir =~ s/</&lt;/g;
$xml_dir =~ s/>/&gt;/g;
$plist =~ s{"\$HOME/dotfiles/scripts/spotify-cache-monitor"}{"$xml_dir/scripts/spotify-cache-monitor"}
  or die "Unexpected ProgramArguments in $source\n";

bootout();
make_path(dirname($target));
open my $out, '>', $target or die "Failed to write $target: $!\n";
print {$out} $plist;
close $out or die "Failed to write $target: $!\n";
say "[COPY] $target (script: $script)";

system($launchctl, 'bootstrap', $domain, $target) == 0
  or die "Failed to start $label\n";
say "[OK] Spotify cache monitor enabled (every Monday 12:00)";
