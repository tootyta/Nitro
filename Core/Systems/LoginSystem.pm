package LoginSystem;

use strict;
use warnings;

use Method::Signatures;
use Digest::MD5 qw(md5_hex);
use Math::Round qw(round);
use Scalar::Util qw(looks_like_number);

use constant XML_HANDLERS => {
	    'verChk' => 'handleVersionCheck',                          
		'rndK' => 'handleRandomKey',				                    
		'login' => 'handleGameLogin'
};

method new($resChild) {
		my $obj = bless {}, $self;
		$obj->{child} = $resChild;
		return $obj;
}

method handleCrossDomainPolicy($objClient) {
		$objClient->sendData("<cross-domain-policy><allow-access-from domain='*' to-ports='" . $self->{child}->{config}->{nitro}->{port}->{value} . "'/></cross-domain-policy>");
}

method handleVersionCheck($strXML, $objClient) {
		return $strXML->{msg}->{body}->{ver}->{v}->{value} == 153 ? $objClient->sendData("<msg t='sys'><body action='apiOK' r='0'></body></msg>") : $objClient->sendData("<msg t='sys'><body action='apiKO' r='0'></body></msg>");
}

method handleRandomKey($strXML, $objClient) {
		$objClient->{penguin}->{lkey} = $self->{child}->{crypt}->generateKey;
		$objClient->sendData("<msg t='sys'><body action='rndK' r='-1'><k>" . $objClient->{penguin}->{lkey} . "</k></body></msg>");
}

method handleGameLogin($strXML, $objClient) {
		my $strUsername = $strXML->{msg}->{body}->{login}->{nick}->{value};
		my $strPassword = $strXML->{msg}->{body}->{login}->{pword}->{value};
		if ($strUsername !~ /^\w+$/) {
			return $objClient->sendError(100);
		}
		my $blnUsernameExist = $self->{child}->{mysql}->checkUsernameExists($strUsername);
		if (!$blnUsernameExist) {
			return $objClient->sendError(100);
		}
		my $blnIncorrectPass = $self->checkPassword($strUsername, $strPassword, $objClient);
		if (!$blnIncorrectPass) {
			$objClient->sendError(101);
			my $intAttempts = $self->{child}->{mysql}->getInvalidLogins($strUsername);
			return $self->{child}->{mysql}->updateInvalidLogins(($intAttempts + 1), $strUsername);
		}
		my $intLoginAttempts = $self->{child}->{mysql}->getInvalidLogins($strUsername);
		if ($intLoginAttempts > 5) {
			return $objClient->sendError(150);
		}
		my $mixBanned = $self->{child}->{mysql}->getBannedStatusByUsername($strUsername);
		if ($mixBanned eq 'PERMANENT') {
			return $objClient->sendError(603);	              
		} elsif (looks_like_number($mixBanned)) {
			if ($mixBanned > time) {
				my $intTime = $self->{child}->{crypt}->getTimeDifference($mixBanned, time, 3600);
				return $objClient->sendError(601 . '%' . $intTime);	
			}              
		}
		if ($self->{child}->{config}->{nitro}->{type}->{value} eq 'login') {
			$objClient->sendData('%xt%gs%-1%' . $self->{child}->{mysql}->generateServerList . '%');  
			$objClient->sendData('%xt%l%-1%' . $self->{child}->{mysql}->getPenguinID($strUsername) . '%' . $self->{child}->{crypt}->reverseHash($objClient->{penguin}->{lkey}) . '%' . $self->{child}->{mysql}->getBuddiesOnline($strUsername, $objClient) .  '%');
			$self->{child}->{mysql}->updateLoginKey($self->{child}->{crypt}->reverseHash($objClient->{penguin}->{lkey}), $strUsername);
		} else {
			if (scalar(keys %{$self->{child}->{sock}->{clients}}) >= $self->{child}->{mysql}->getServerLimit($self->{child}->{config}->{nitro}->{port}->{value})) {
				return $objClient->sendError(103);
			}
			$objClient->{penguin}->{ID} = $self->{child}->{mysql}->getPenguinID($strUsername);
			$self->{child}->{mysql}->updateOnlineStatus(1, $objClient->{penguin}->{ID});
			$objClient->loadInformation;
			$objClient->sendXT(['l', '-1']);
			$objClient->handleBuddyOnline;
		}
		$self->{child}->{mysql}->updateInvalidLogins(0, $objClient->{penguin}->{username});
}

method checkPassword($strUsername, $strPassword, $objClient) {
	    my $strDBPass = $self->{child}->{mysql}->getPenguinPassword($strUsername);
	    my $strDBLoginKey = $self->{child}->{mysql}->getPenguinLoginKey($strUsername);
		my $strHash = $self->generateHash($strDBPass, $strDBLoginKey, $objClient);
		return ($strPassword eq $strHash) ? 1 : 0;
}

method generateHash($strDBPass, $strDBLoginKey, $objClient) {
       my $strLoginKey = $objClient->{penguin}->{lkey};
       my $strLoginHash = $self->{child}->{crypt}->digestHash(uc($strDBPass), $strLoginKey);                            
       my $strGameHash = $self->{child}->{crypt}->swapHash(md5_hex($strDBLoginKey . $strLoginKey)) . $strDBLoginKey;
       my $strType = $self->{child}->{config}->{nitro}->{type}->{value};
       my $strHash = $strType eq 'login' ? $strLoginHash : $strGameHash;
       return $strHash;
}

1;
