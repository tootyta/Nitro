package Cryptography;

use strict;
use warnings;

use Method::Signatures;
use Digest::MD5 qw(md5_hex);
use Bytes::Random::Secure qw(random_string_from);
use Math::Round qw(round);

method new {
		my $obj = bless {}, $self;
		return $obj;
}

method digestHash($strPassword, $strKey) {
		my $strHash = $self->swapHash(md5_hex($self->swapHash($strPassword) . $strKey . 'Y(02.>\'H}t":E1'));
		return $strHash;
}

method swapHash($strHash) {
		my $strSwapped = substr($strHash, 16, 16);
		$strSwapped .= substr($strHash, 0, 16);
		return $strSwapped;
}

method reverseHash($strKey) {
		my $revKey = reverse($strKey);
		my $strHash = md5_hex($revKey);
		return $strHash;
}

method generateKey {
		my $strKey = random_string_from(join( '', ('a' .. 'z'), ('A' .. 'Z'), ('0' .. '9'), ('_')), 12);
		return $strKey;
}

method generateRandomNumber($intMin, $intMax) {
		my $intRand = rand($intMax - $intMin);
		my $intFinal = int($intMin + $intRand);
		return $intFinal;
}

method getTimeDifference($intPastTime, $intCurrentTime, $intFormat) {
		my $intDifference = round(($intPastTime - $intCurrentTime) / $intFormat);
		return $intDifference; 
}

1;
