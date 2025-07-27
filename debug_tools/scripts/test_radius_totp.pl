#!/usr/bin/perl
use strict;
use warnings;
use File::Temp qw(tempfile);

# 引数チェック
if (@ARGV < 4 || @ARGV > 5) {
    die "使い方: $0 <ユーザー名> <パスワード> <OTP> <RADIUSサーバーIP> [ポート]\n";
}

my ($username, $password, $otp, $server, $port) = @ARGV;
$port = $port || 1812; # デフォルトポート

# clients.confからシークレットを読み込む
sub read_radius_secret {
    my @possible_paths = (
        "../freeradius/conf/clients.conf",  # 通常のscriptsディレクトリから
        "/freeradius/conf/clients.conf",    # debug_toolsコンテナ内から
        "./freeradius/conf/clients.conf"    # プロジェクトルートから
    );
    
    # スクリプトディレクトリからの相対パス
    my $script_dir = $0;
    $script_dir =~ s/[^\/]*$//;
    
    my $clients_conf;
    for my $path (@possible_paths) {
        my $full_path = ($path =~ m{^/}) ? $path : $script_dir . $path;
        if (-r $full_path) {
            $clients_conf = $full_path;
            last;
        }
    }
    
    die "clients.confが見つかりません。以下のパスを確認してください:\n" . 
        join("\n", map { ($_ =~ m{^/}) ? $_ : $script_dir . $_ } @possible_paths) . "\n"
        unless $clients_conf;
    
    open(my $fh, '<', $clients_conf) or die "clients.confが読み込めません: $clients_conf ($!)\n";
    
    while (my $line = <$fh>) {
        chomp $line;
        # secret = の行を探す（前後の空白は正規表現で除外）
        if ($line =~ /^\s*secret\s*=\s*(\S+(?:\s+\S+)*)\s*$/) {
            my $secret = $1;
            close($fh);
            return $secret;
        }
    }
    
    close($fh);
    die "clients.confでシークレットが見つかりません\n";
}

my $secret = read_radius_secret();

# 一時ファイル作成（安全な方法）
my ($auth_fh, $auth_request_file) = tempfile(UNLINK => 1);
my ($secret_fh, $secret_file) = tempfile(UNLINK => 1);

# シークレットファイルの作成（安全な方法）
print $secret_fh $secret;
close($secret_fh);

# ステップ1: パスワード送信
print $auth_fh "User-Name = $username\n";
print $auth_fh "User-Password = $password\n";
print $auth_fh "NAS-IP-Address = 127.0.1.1\n";
print $auth_fh "NAS-Port = 1812\n";
print $auth_fh "Message-Authenticator = 0x00\n";
close($auth_fh);

my $response1 = `radclient -x -S $secret_file $server:$port auth < $auth_request_file`;

# State 抽出
my ($state) = $response1 =~ /State = ([0-9a-fx]+)/i;

if (!$state) {
    print "チャレンジが返されませんでした。認証失敗またはTOTP未設定の可能性があります。\n";
    exit 2;
}

print "チャレンジ受信: State = $state\n";

# ステップ2: OTP送信
my ($otp_fh, $otp_request_file) = tempfile(UNLINK => 1);
print $otp_fh "User-Name = $username\n";
print $otp_fh "User-Password = $otp\n";
print $otp_fh "State = $state\n";
print $otp_fh "NAS-IP-Address = 127.0.1.1\n";
print $otp_fh "NAS-Port = 1812\n";
print $otp_fh "Message-Authenticator = 0x00\n";
close($otp_fh);

my $response2 = `radclient -x -S $secret_file $server:$port auth < $otp_request_file`;

print "認証結果:\n$response2";

# File::Tempで一時ファイルは自動削除

