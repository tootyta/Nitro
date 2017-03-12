package Navigation;

use strict;
use warnings;

use Method::Signatures;

method new($resChild) {
		my $obj = bless {}, $self;
		$obj->{child} = $resChild;
		$obj->{handlers} = {
			jp => 'handleJoinPlayer',
			js => 'handleJoinServer',
			jr => 'handleJoinRoom',
			jg => 'handleJoinGame',
			grs => 'handleGetRoomSynced'
		};
		return $obj;
}

method handleNavigation(\@arrData, $objClient) {
		my $strHandle = $arrData[0];
		my $strData = $arrData[1];
		return if (!exists($self->{handlers}->{$strHandle}));
		my $strMethod = $self->{handlers}->{$strHandle};
		if ($self->can($strMethod)) {
			$self->$strMethod($strData, $objClient);
		}
}

method handleJoinPlayer($strData, $objClient) {
		my @arrData = split('%', $strData);
		my $intRoom = $arrData[5];
		if ($intRoom < 1000) {
			$intRoom += 1000;
		}
		$objClient->sendXT(['jp', '-1', $intRoom]); 
		$objClient->joinRoom($intRoom);
}

method handleJoinServer($strData, $objClient) {
		my @arrData = split('%', $strData);
		my $strLoginKey = $arrData[6];
		my $strKey = $self->{child}->{mysql}->getPenguinLoginKey($objClient->{penguin}->{username});
		if ($strLoginKey eq '' || $strLoginKey ne $strKey) {
			$objClient->sendError(101);
			my $intAttempts = $self->{child}->{mysql}->getInvalidLogins($objClient->{penguin}->{username});
			$self->{child}->{mysql}->updateInvalidLogins($intAttempts + 1, $objClient->{penguin}->{username});
			return $self->{child}->{sock}->handleRemoveClient($objClient->{sock});
		}
		$self->{child}->{mysql}->updateLoginKey('', $objClient->{penguin}->{username});
		$objClient->sendXT(['js', '-1', 0, 1, $objClient->{penguin}->{ranking}->{isStaff}, 0]);
		$objClient->sendData('%xt%lp%-1%' . $objClient->buildPenguinString . '%' . $objClient->{penguin}->{wallet} . '%0%1440%100%' . $objClient->{penguin}->{joindate} . '%4%' . $objClient->{penguin}->{joindate} . '%%7%');
		$objClient->sendXT(['gps', '-1', $objClient->{penguin}->{ID}, join('|', @{$objClient->{stampbook}->{stamps}})]);
		$objClient->joinRoom;  
		$objClient->updatePuffleStatistics; 
		$self->{child}->{mysql}->updateLastLogin($objClient->{penguin}->{ID});
}

method handleJoinRoom($strData, $objClient) {
		my @arrData = split('%', $strData);
		my $intRoom = $arrData[5];
		$objClient->joinRoom($intRoom);
}

method handleJoinGame($strData, $objClient) {
		my @arrData = split('%', $strData);
        my $intRoom = $arrData[5];
        $objClient->joinRoom($intRoom);
}

method handleGetRoomSynced($strData, $objClient) {
		$objClient->sendData('%xt%grs%-1%' . $objClient->{room}->{id} . '%' . $objClient->buildPenguinString);
}

1;
