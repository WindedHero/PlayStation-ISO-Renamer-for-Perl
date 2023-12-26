#!/usr/bin/perl --
use utf8;
use Encode;
use File::Copy;
use VirtualFS::ISO9660;
my $dir = ".";
opendir DIR,$dir;
my @dir = readdir(DIR);
close DIR;
#use warnings;
foreach $object (@dir) {
	my $file = $dir . "\\" . $object;
	next unless $file =~ m/\.iso$/gi;
	if (-f $file){
		my $filename;
		my %ENTRY;
		my @DATA;
		print "\n\n###$file###\n";
		my $ref = new VirtualFS::ISO9660($file) or die "\nCan't open $file: $!";
		$ref = new VirtualFS::ISO9660($file, -verbose => 1);
		%all_ids = $ref->identifier;
		#foreach (keys %all_ids) {print $_ . " => $all_ids{$_}\n";}
		$one_id  = $ref->identifier('system');
		@several_ids = $ref->identifier('system', 'publisher');
		my $umd_data_bin;
		$ref->open($umd_data_bin, "<", '/UMD_DATA.BIN') or die "\nCan't open UMD_DATA.BIN in $file";
		#print "\n###UMD_DATA.BIN###";
		my $ID;
		for (my $terminated = 0; $terminated < 1; ) {
			my $byte;
			my $byte_to_hex;
			read($umd_data_bin, $byte, 1, 0);
			$byte_to_hex = uc unpack 'H*', $byte;
			$ID = $ID . $byte_to_hex;
			if (uc unpack 'H*', $byte_to_hex eq "7C") {$terminated++;}
		}
		$ID = pack('H*', $ID);
		$ID =~ s/(\x0*|\s*)\|$//;
		my $Key;
		for (my $terminated = 0; $terminated < 1; ) {
			my $byte;
			my $byte_to_hex;
			read($umd_data_bin, $byte, 1, 0);
			$byte_to_hex = uc unpack 'H*', $byte;
			$Key = $Key . $byte_to_hex;
			if (uc unpack 'H*', $byte_to_hex eq "7C") {$terminated++;}
		}
		$Key = pack('H*', $Key);
		$Key =~ s/(\x0*|\s*)\|$//;
		my $Unknown;
		for (my $terminated = 0; $terminated < 1; ) {
			my $byte;
			my $byte_to_hex;
			read($umd_data_bin, $byte, 1, 0);
			$byte_to_hex = uc unpack 'H*', $byte;
			$Unknown = $Unknown . $byte_to_hex;
			if (uc unpack 'H*', $byte_to_hex eq "7C") {$terminated++;}
		}
		$Unknown = pack('H*', $Unknown);
		$Unknown =~ s/(\x0*|\s*)\|$//;
		my $Category;
		for (my $terminated = 0; $terminated < 1; ) {
			my $byte;
			my $byte_to_hex;
			read($umd_data_bin, $byte, 1, 0);
			$byte_to_hex = uc unpack 'H*', $byte;
			$Category = $Category . $byte_to_hex;
			if (uc unpack 'H*', $byte_to_hex eq "7C") {$terminated++;}
		}
		$Category = pack('H*', $Category);
		$Category =~ s/(\x0*|\s*)\|$//;
		print "ID = $ID\nKey = $Key\nUnknown = $Unknown\nCategory = $Category\n";
		#print "\n###END UMD_DATA.BIN###\n###START OF PARAM.SFO###\n";
		my ($header_magic, $header_version, $header_key_table_start, $header_data_table_start, $header_tables_entries);
		if ($Category eq "V") { #UMD category is Video
			$ref->open($param_sfo, '<', '/UMD_VIDEO/PARAM.SFO') or die "\nCan't open PARAM.SFO in $file";
		}
		if ($Category eq "G") { #UMD category is Game
			$ref->open($param_sfo, '<', '/PSP_GAME/PARAM.SFO') or die "\nCan't open PARAM.SFO in $file";
		}
		my $current_cursor;
		read($param_sfo, $header_magic, 4, 0);$current_cursor+=4;
		$header_magic = uc unpack 'H*', $header_magic;
		$header_magic = pack 'H*', $header_magic;
		#print "header_magic = \'$header_magic\'\n";
		read($param_sfo, $header_version, 4, 0);$current_cursor+=4;
		$header_version = uc unpack 'H*', $header_version;
		#print "header_version = \'$header_version\'\n"; 
		for (my $current_byte = 0; $current_byte < 4; $current_byte++) {
			my $byte;
			read($param_sfo, $byte, 1, 0);$current_cursor+=1;
			$header_key_table_start = uc(unpack('H*', $byte)) . $header_key_table_start;
			#$header_key_table_start =~ s/0+$//g;
		}
		#$header_key_table_start = hex($header_key_table_start);
		print "header_key_table_start = \'$header_key_table_start\' (hex address)\n";
		for (my $current_byte = 0; $current_byte < 4; $current_byte++) {
			my $byte;
			read($param_sfo, $byte, 1, 0);$current_cursor+=1;
			$header_data_table_start = uc(unpack('H*', $byte)) . $header_data_table_start;
			#$header_data_table_start =~ s/0+$//g;
		}
		#$header_data_table_start = hex($header_data_table_start);
		print "header_data_table_start = \'$header_data_table_start\' (hex address)\n";
		read($param_sfo, $header_tables_entries, 4, 0);$current_cursor+=4;
		$header_tables_entries = uc unpack 'H*', $header_tables_entries;
		$header_tables_entries =~ s/0+$//g;#this is wrong but it works for now-- 03000000 should be read by programs as 3. not sure how to convert binary-stored decimals to actual decimals safely
		$header_tables_entries = hex($header_tables_entries);
		print "header_tables_entries = \'$header_tables_entries\'\n";
		#print "cursor at $current_cursor (hex address " . sprintf("0x%X",$current_cursor) . ")\n";
		for (my $current_header_entry = 0; $current_header_entry < $header_tables_entries; $current_header_entry++) {
			#print "Header Table Entry " .($current_header_entry+1) . "\n";
			my $index_table_key_offset;
			read($param_sfo, $index_table_key_offset, 2, 0);$current_cursor+=2;
			$index_table_key_offset = uc unpack 'H*', $index_table_key_offset;
			print "index_table_key_" . ($current_header_entry+1) . "_offset = \'$index_table_key_offset\'\n";
			my $index_table_data_fmt;
			read($param_sfo, $index_table_data_fmt, 2, 0);$current_cursor+=2;
			$index_table_data_fmt = uc unpack 'H*', $index_table_data_fmt;
			#if ($index_table_data_fmt eq '0400') {$index_table_data_fmt = "utf8 Special Mode, NOT NULL terminated";}
			#if ($index_table_data_fmt eq '0402') {$index_table_data_fmt = "utf8 character string, NULL terminated (0x00)";}
			#if ($index_table_data_fmt eq '0404') {$index_table_data_fmt = "integer 32 bits unsigned";}
			print "index_table_data_" . ($current_header_entry+1) . "_fmt = \'$index_table_data_fmt\'\n";
			my $index_table_data_len;
			for (my $current_byte = 0; $current_byte < 4; $current_byte++) {#slurp 4 bytes for this variable
				my $byte;
				read($param_sfo, $byte, 1, 0);$current_cursor+=1;
				$index_table_data_len = uc(unpack('H*', $byte)) . $index_table_data_len;
			}
			$index_table_data_len = hex($index_table_data_len);
			print "index_table_data_" . ($current_header_entry+1) . "_len = \'$index_table_data_len\' (bytes)\n";
			my $index_table_data_max_len;
			#print "cursor at $current_cursor (hex address " . sprintf("0x%X",$current_cursor) . ")\n";
			for (my $current_byte = 0; $current_byte < 4; $current_byte++) {#slurp 4 bytes for this variable
				my $byte;
				read($param_sfo, $byte, 1, 0);$current_cursor+=1;
				$index_table_data_max_len = uc(unpack('H*', $byte)) . $index_table_data_max_len;
			}
			$index_table_data_max_len = hex($index_table_data_max_len);
			#print "index_table_data_" . ($current_header_entry+1) . "_max_len = \'$index_table_data_max_len\' (bytes)\n";
			my $index_table_data_offset;
			read($param_sfo, $index_table_data_offset, 4, 0);$current_cursor+=4;
			$index_table_data_offset = uc unpack 'H*', $index_table_data_offset;
			#print "index_table_data_" . ($current_header_entry+1) . "_offset = \'$index_table_data_offset\'\n";
			push(@DATA, {
				'index_table_key_offset' => $index_table_key_offset,
				'index_table_data_fmt' => $index_table_data_fmt,
				'index_table_data_len' => $index_table_data_len,
				'index_table_data_max_len' => $index_table_data_max_len,
				'index_table_data_offset' => $index_table_data_offset});
		}
		#print "cursor entering key table at char $current_cursor (hex address " . sprintf("0x%X",$current_cursor) . ")\n";
		for (my $current_key = 0; $current_key < $header_tables_entries; $current_key++) {
			my $key_table_key;
			for (my $terminated = 0; $terminated < 1; ) {
				my $byte;
				my $byte_to_hex;
				read($param_sfo, $byte, 1, 0);$current_cursor+=1;
				$byte_to_hex = uc unpack 'H*', $byte;
				$key_table_key = $key_table_key . $byte_to_hex;
				if (uc unpack 'H*', $byte_to_hex eq "00") {$terminated++;}
			}
			$key_table_key = pack 'H*', $key_table_key;
			print "key_table_key_" . ($current_key+1) . " = \'$key_table_key\'\n";
			$DATA[$current_key]{'key_table_key'} = $key_table_key;
		}
		if (($current_cursor % 4) > 0) {
			#key table needs padded;
			$padding_to_read = ((($current_cursor % 4)*-1)+4);
			read($param_sfo, $padding, $padding_to_read, 0);
			$current_cursor = ($current_cursor+$padding_to_read);
			#print "shifted cursor to $current_cursor (buffer required for 4-byte alignment)\n";
		}
		#print "cursor entering data table at char $current_cursor (hex address " . sprintf("0x%X",$current_cursor) . ")\n";
		for ($current_data_table_data_entry = 0; $current_data_table_data_entry < $header_tables_entries; $current_data_table_data_entry++) {
			my $table_data;
			#print "reading $DATA[$current_data_table_data_entry]{'index_table_data_max_len'} bytes for data table entry $current_data_table_entry\n";
			if ($DATA[$current_data_table_data_entry]{'index_table_data_fmt'} eq '0402') {
				#utf8 character string, NULL terminated (0x00)
				read($param_sfo, $table_data, $DATA[$current_data_table_data_entry]{'index_table_data_max_len'}, 0);$current_cursor+=$DATA[$current_data_table_data_entry]{'index_table_data_max_len'};
				$table_data = uc unpack 'H*', $table_data;
				$table_data = pack 'H*', $table_data;
			}
			if ($DATA[$current_data_table_data_entry]{'index_table_data_fmt'} eq '0404') {
				#integer 32 bits unsigned
				for (my $current_byte = 0; $current_byte < $DATA[$current_data_table_data_entry]{'index_table_data_max_len'}; $current_byte++) {#slurp $DATA[$current_data_table_data_entry]{'index_table_data_max_len'} bytes for this variable
					my $byte;
					read($param_sfo, $byte, 1, 0);$current_cursor+=1;
					$table_data = uc(unpack('H*', $byte)) . $table_data;
				}
			}
			$DATA[$current_data_table_data_entry]{'data'} = $table_data;
			print "data_table_data_" . ($current_data_table_data_entry+1) . " = \'$table_data\' (max length $DATA[$current_data_table_data_entry]{'index_table_data_max_len'}, length $DATA[$current_data_table_data_entry]{'index_table_data_len'}) \n";
			#print "cursor at $current_cursor (hex address " . sprintf("0x%X",$current_cursor) . ")\n";
		}
		my $iterator = 0;
		foreach (@DATA) {
			#print "$DATA[$iterator]{'key_table_key'} => $DATA[$iterator]{'data'}\n";
			$DATA[$iterator]{'key_table_key'} =~ s/\x0$//;
			$DATA[$iterator]{'key_table_key'} =~ s/\x0+$//;
			$DATA[$iterator]{'key_table_key'} =~ s/(\!|\?|\:)//;
			$DATA[$iterator]{'data'} =~ s/\x0+$//;
			$DATA[$iterator]{'data'} =~ s/\s+$//;
			$DATA[$iterator]{'data'} =~ s/(\!|\?|\:)//;
			$ENTRY{$DATA[$iterator]{'key_table_key'}} = $DATA[$iterator]{'data'};
			$iterator++;
		}
		foreach (keys %ENTRY) {
			print "$_ => $ENTRY{$_}\n";
		}
		if (($ID ne "")&&($ENTRY{'TITLE'} ne "")) {
			$ID =~ s/\x0+$//;
			$ID =~ s/\s+$//;
			$ID =~ s/(\!|\?|\:)//;
			$ENTRY{'TITLE'} =~ s/\x0+$//;
			$ENTRY{'TITLE'} =~ s/\s+$//;
			$ENTRY{'TITLE'} =~ s/(\!|\?|\:)//;
			$filename = "[$ID] $ENTRY{'TITLE'}";
		}
		elsif (($ENTRY{'DISC_ID'} ne "")&&($ENTRY{'TITLE'} ne "")) {
			$ID =~ s/\x0+$//;
			$ID =~ s/\s+$//;
			$ID =~ s/(\!|\?|\:)//;
			$ENTRY{'TITLE'} =~ s/\x0+$//;
			$ENTRY{'TITLE'} =~ s/\s+$//;
			$ENTRY{'TITLE'} =~ s/(\!|\?|\:)//;
			$filename = "[$ENTRY{DISC_ID}] $ENTRY{TITLE}";
		}
		elsif ($ENTRY{'TITLE'} ne "") {
			$ENTRY{'TITLE'} =~ s/\x0+$//;
			$ENTRY{'TITLE'} =~ s/\s+$//;
			$ENTRY{'TITLE'} =~ s/(\!|\?|\:)//;
			$filename = "$ENTRY{'TITLE'}";
		}
		if ($ENTRY{'DISC_VERSION'} ne "") {
			$ENTRY{'DISC_VERSION'} =~ s/\x0+$//;
			$ENTRY{'DISC_VERSION'} =~ s/\s+$//;
			$ENTRY{'DISC_VERSION'} =~ s/(\!|\?|\:)//;
			$filename = $filename . " (ver $ENTRY{'DISC_VERSION'})";
		}
		print "rename $file, C:\\ISO\\$filename\.iso";
		undef $ref;
		undef $param_sfo;
		undef $umd_data_bin;
		rename ($file, "$filename\.iso") || die "Error: $!";
	}
	else {
		#this isn't a file (more likely a directory
		next;
	}
	undef %ENTRY;
}
$iterator = 0;
	
#$ref->opendir($dh, '/') or die "Can't open rootdir in $file\n";
#print "\nfiles in $file's root directory:\n";
#for ($dh->readdir) { print "\t$_\n"; }
#print "\nlet's see that again!\n";
#$dh->rewinddir();
#for ($dh->readdir) { print "\t$_\n"; }