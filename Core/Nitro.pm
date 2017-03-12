package Nitro;

use strict;
use warnings;

use Method::Signatures;
use XML::Bare;
use Hash::Merge::Simple qw(merge);
use File::Slurp;
use Cwd;
use feature qw(say);

use sigtrap 'handler' => \&handleSignals, 'normal-signals';
use sigtrap 'handler' => \&handleSignals, 'error-signals';

method handleSignals {}

method new(\@arrConfig) {
       my $obj = bless {}, $self;
       $obj->initSource(\@arrConfig);
       return $obj;
}

method initSource(\@arrConfig) {
	   $self->displayAscii;
	   $self->loadModules;
	   $self->parseConfig(\@arrConfig);
       $self->initRockets;
}

method displayAscii {
		my $ascii = read_file(cwd() . "/header.txt");
		print $ascii . chr(10);
}

method parseConfig(\@arrConfig) {
	    my ($resServConf, $resDBConf) = @arrConfig;
		my $arrServConf = $self->parseXML('file', $resServConf) or die($self->{logger}->error('Failed to read server configuration'));
		my $arrDBConf = $self->parseXML('file', $resDBConf) or die($self->{logger}->error('Failed to read database configuration'));
		$self->{logger}->info('Successfully loaded configuration');
		my $arrConfig = merge($arrServConf, $arrDBConf);
		$self->{config} = $arrConfig;
}

method loadModules {
		$self->{logger} = Logger->new();
		$self->{crumbs} = Crumbs->new($self);
		$self->{crypt} = Cryptography->new();
		$self->{mysql} = MySQL->new($self);
		$self->{sock} = Socket->new($self);
		$self->{loginsys} = LoginSystem->new($self);
		$self->{gamesys} = GameSystem->new($self);
		$self->{spamsys} = SpamSystem->new($self);
		$self->{multiplayer} = Multiplayer->new($self);
}

method initRockets {
		$self->{crumbs}->loadCrumbs() unless ($self->{config}->{nitro}->{type}->{value} eq 'login');
		$self->connectMySQL;
		$self->createServer;
		$self->connectServer;
}

method connectMySQL {
		$self->{mysql}->connectMySQL($self->{config}->{nitro}->{mysql}->{host}->{value}, $self->{config}->{nitro}->{mysql}->{username}->{value}, $self->{config}->{nitro}->{mysql}->{password}->{value}, $self->{config}->{nitro}->{mysql}->{database}->{value});
}

method createServer {
		if ($self->{config}->{nitro}->{type}->{value} eq 'game') {
			$self->{mysql}->createGameServer($self->{config}->{nitro}->{port}->{value}, $self->{config}->{nitro}->{server_name}->{value}, $self->{config}->{nitro}->{server_ip}->{value});
        }
}

method connectServer {
		$self->{sock}->createSocket($self->{config}->{nitro}->{port}->{value}) or die($self->{child}->{logger}->error('Failed to connect to ' . ucfirst($self->{config}->{nitro}->{type}->{value}) . ' server'));
		$self->{logger}->info('Successfully connected to ' . ucfirst($self->{config}->{nitro}->{type}->{value}) . ' server');
		$self->{logger}->notice('You may not login to the game!') if ($self->{config}->{nitro}->{type}->{value} eq 'game');
}

method parseXML($strType, $mixData) {
		my $strXML;
		eval {
		   $strXML = XML::Bare->new($strType => $mixData)->parse;
		};
		if ($@) {
			$self->{child}->{logger}->warn("Invalid xml: $@");
			return 0;
		}
		return $strXML;
}

1;
