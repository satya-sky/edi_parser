# EDI PARSER version 11
# 2020/08/24 SB: Updated KWI logic to change Date format from YYMMDD to YYYYMMDD in GS and XQ segmants (Task #37202)
#				 Removed trailing and leading spaces for GS segment tpid (Task #37202)
#				 Added $send_date to GS segment for KWI_BLUE for correct archiving (Task #37202) 
#********************************************************************************************************************************************************************************
# EDI PARSER version 10
# 2020/07/29 SB: Updated KWI logic to parse prices.
#********************************************************************************************************************************************************************************
# EDI PARSER version 9
# 2020/07/16 SB: Updated code to resolve archiving issue with additional 0's in months and days (ex: incorrect - 2020007004 | correct - 20200704 ).
#********************************************************************************************************************************************************************************
# EDI PARSER version 8
# 2019/07/30 SB: Create archive folder (Daily) and move daily files to the folder.
#********************************************************************************************************************************************************************************
# EDI PARSER version 7
# 2019/05/20 AR: create a switch variable for backing up files.
#********************************************************************************************************************************************************************************
# EDI PARSER version 6
# 2019/05/07  SC  Updated KWI logic (used previously by KWITHEORY) to manage BlueMercury (KWIBLUE). (Archiving still needs to be adjusted)
# 2019/05/09  SC Change date size to 8 bytes on XQA segment for KWI files;
# 2019/05/09  SC Added logic to KWI process to allow the archive locations will be correctly moved in the production version.
# 2019/05/10  SC Removed the century hard code value for GS segment.  KWI now uses 8 character date values
#********************************************************************************************************************************************************************************
# EDI PARSER version 5
# 2019/05/07  SC  Added logic to truncate $style values to 14 characters max.  for EDI 852 LIN segment process. (Not added to the 856 LIN process)
# 2019/04/29  SC  Replaced the forward slash '/' with a dash '-' on LIN record for L'Oreal data from JCP  Line 205
# 2019/03/21 	SC 	Remove Boscov's *ONLY string in the LIN record  found in Boscov's data for L'Oreal.  Line 202
# 2019/02/27  AR  Removed '/' from being considered as delimiter. It affects AAFES Store Numbers
#********************************************************************************************************************************************************************************
# EDI PARSER version 4
# 2015/07/17  	SC	Removing the logic to keep the price values for transactions provided without price.
# 2015/08/12	SC	Added a truncation for VA entery longer than 14 bytes.  Problem with GIII 856 for Steinmart.
#					The chang is in the LIN segment process.  Search for "2015/08/12" to find it.
# 2015/08/27	SC  Added logic to bypass printing the duplicate LIN and it's descendent segment for tow HBC TPIDs.  The process relies on having the value "RES" in the first
#					instance of the CTP segment.  If the "RES" string is mssing, HBC data will generate correctly.  If other HBC owned retailers adapt this logic, we will
#					need to add those TPIDs to the logic.  (searh for 2015/08/27 to find the row to be altered.
# 2015/09/02	SC	Added new logic to automatically move each file it processes to a designated backup directory.  To accomplish this, the user must provide a new 4th parameter
#					in the call to this program that will designate ther root folder where the backup is to be created.  The logic uses the week ending date value from the XQ segment
#					Consequently the data will be archived into the date structure the data pertains to and not to the current week.  By providing the value 'NO' in the 4th position
#					you will suppress the archive move, leaving the source files in place.
# 2016/02/18 	SC	Fix for a problem where a file failes to write out some, or all, LIN and subsequent lines.  The problem was with the $skip variable, which is set to 1 after a HBC record is written
#					so that the duplicate that follows will not be written.  Moved a reset point for the $skip up to the file level, so it is reset with every new file opened.
# 2016/03/21	SC	Changed the BJS logic to identify the store number:  The trim was altered to pick up only the last 3 characters only from the NA*RL segment.
# 2016/12/09    SC  Changed the store number field in the N1A segment for 856 to 14 digits from 10 to accommodate Meijer's shipment from some of our clients. Line 174


#!
use FileHandle;
use Date::Calc qw(:all);

if((-e "$ARGV[1]") && ("$ARGV[4]" ne 'r')) {
  open(OUT, ">>$ARGV[1]") || die("Could not open target file (852)! ($ARGV[1])");
}
else {
  open(OUT, ">$ARGV[1]") || die("Could not open target file (852)! ($ARGV[1])");
}
if((-e "$ARGV[2]") && ("$ARGV[4]" ne 'r')){
  open(OUT2, ">>$ARGV[2]") || die("Could not open target file (856)! ($ARGV[2])");
}
else {
  open(OUT2, ">$ARGV[2]") || die("Could not open target file (856)! ($ARGV[2])");
#  print "\n$ARGV[2]";
}
if((-e "$ARGV[3]") && ("$ARGV[4]" ne 'r')){
  open(OUT3, ">>$ARGV[3]") || die("Could not open target file (846)! ($ARGV[3])");
}
else {
  open(OUT3, ">$ARGV[3]") || die("Could not open target file (846)! ($ARGV[3])");
}
#	Code to read in the source directory contents
 open (HOLD, ">", "c:\\spa\\hold.txt") || die("Could not open HOLD");	# Production code
#  open (HOLD, ">", "c:\\temp\\hold.txt") || die("Could not open HOLD");	# Test code
#print "$ARGV[0]\n";
system "dir $ARGV[0] > c:\\spa\\zx.txt" ;		# Production code
my $dh = new FileHandle 'c:\spa\zx.txt', "r";		# Production code
#system "dir $ARGV[0] > c:\\temp\\zx.txt" ;		# Test code
#my $dh = new FileHandle 'c:\temp\zx.txt', "r";		# Test code
die "Unable to open directory listing source: $!\n" unless $dh;
my $c = 0;
my $fc = 0;
my @filelist;
my @filelength;
my $filecounter = 0;
my $dot = '.';
my $k = 0;
my $b = 0;				# Counter for the blocks within a file
my $instream;			# full record from source file
my $unit = undef;		# Used to check for a change between EA and DO flags at the detail level
my $last_unit = 'xx';	# Used to check for a change between EA and DO flags at the detail level
my $zarecord = undef;	# Record image holder
my $fl;					# File length variable
my $isacount = undef;	# Set up a counter to locate multiple transmissions in one file
my $kwi = 0;			# Set a flag to figure out KWI 852 data from Edifice ( 0 is false 1 is true)
my $price = undef;		# Price variable to get price at the store level
my $upc;				# UPC Code value for the LIN segment (To make accepting styles instead of UPC codes possible in 852)
my $lastupc;			# Keeps the previous UPC number for cases where the price record is not sent after each LIN segment
my $style;				# Style number for the LIN segment
my $upctype;			# UPC type field for the LIN segment
my $styletype = 'IT';	# Style type field for the LIN segment
my $linseq;				# LIN Record Sequence Number
my $RES_price;			# RES Price from the CTP Record
my $UCP_price;			# UCP Price (Unit Cost Price) from the CTP Record
my $linprint = 1;		# Flag to check if the LI record has been printed or not
my $more = 0;   		# set up a way to add more stores than 10 in one line
my $blank = ' ';		# Just a filler
my $tdid = undef;		# Setting to isolate the two different TD1 records (one belongs to HLA the other HLO segment). Don't know if it matters
my $tdname = undef;		# Field to print the current value of TD1 segment ID based which HL segment its associated with
my $n1_storenum= undef;	# Store number for the AAFES and BJ's EDI data that has the store number in the N1 segment
my $tpid = undef;		# Trade Partner ID from the GS segment
my $tilde = '~';		# Tilde character for segment separation
my $check = 0;			# Flag to check whether or not to chomp
my $skip = 0;			# Skip printing flag ro HBC duplicate LIN and descending segments.
my $filetype;			# For achiving we need whether it is an  852 or an 856
my ($archive, $archive_date, $arch_yr, $arch_mo, $arch_dt,$send_date, $ending_date,$year,$month,$day,$send_year,$send_month,$send_day,$send_dow,$done,$ship_date,$Dd,$arch_flag,$daily,$xq_start,$xq_end,$block,$detail,$l,$store,$dow);	# archive directory names
my @lin_segment;        # this variable stores line segment info before outputting
my @za_segment;		    # this variable stores za segment info before outputting
my ($len_za_segment, $za_metric_type, $za_units, $za_element); # for storing elements for KWIBLUE prices
$lin_tracker = 0;

while (<$dh>) {
	chomp;
	if ($c > 6){
		my @tmp = split / /, $_;
		my $filename = $ARGV[0]."\\".@tmp[$#tmp];	# Appends the name of the file to the path
		print "$filename \n" ;
		$fl = @tmp[$#tmp-1];		# Get the length of the file
		$fl =~ s/,//g;			# Remove commas from the length
		if (@tmp[$#tmp] ne "bytes" and @tmp[$#tmp] ne "free"){
			push(@filelist, $filename);
			push(@filelength, $fl);
			$fc ++;			# Increment file counter
			}
		#print "Filename is $filename in @tmp \n";
	}
	$c ++;
}
#	Directory contents completed
print "Processing $fc files: \n";
#@filelist = reverse sort @filelist;	# Put the newest file (the one with the highest transacion#) on top
foreach $file (@filelist){
	print "   $file \n";
}
foreach $file (@filelist){
	close $fh unless ! $fh;
#	print "$file /n";
	my $fh = new FileHandle $file, "r";
	die "\nUnable to open: $file: $!\n" unless $fh;
#	my $i = 0;	# Counter for the number of blocks inside a file
	$b = 0;		# Counter for the blocks within a file
	my $j = 0;	# Counter for the number of lines processed
	my $II = 0;
	$instream = '';	# Reset the receiver to empty
	my @pth = split /\//, $ARGV[0] ;  # Get the file name processed
	$fl = shift(@filelength);	# Pull the length paramter for the current file
	$filecounter ++;	# Counting the number of files processed
	$isacount = 0;		# Zero out the ISA record type counter
	$check = 0;			# Reset the check flag for each file
	while (<$fh>) {		# Read the contents of the current file
		my $srch = "BJS";
		my $srch2 = "054116012";
		if(index ($_, $srch) > 0 or index($_,"054116012") > 0){
			$check=1;
		}
		if ($check > 0){	# Just do this for BJS file
			chomp;
#			die;
#			print "Found! at $ii Check# $check\n";
		}	# If the line lenght is 80 bytes, it is broken into standard length records. Purge the OD OA combo.
		#s/\s+$//;	# Get rid of trailing blanks (Removed from code due to this command also taking out x0a line feed character.
		#chomp;
		$instream .= $_;	# Concatenate each row
	}
	$_ = $instream;	#Move the data into the default scalar operator
#	$i ++;
	@tmp = split /\\/, $file;
	my $name = @tmp[$#tmp];		# Extract the original file name
	my $filename = $name;
	@tmp = split /\./, $name;	# Split the name along the dots
	$name = @tmp[$#tmp-1].$dot. @tmp[$#tmp];
	s/\x0D//g;
	s/\x0A/\x25/g;
#	print {OUT3}"$_";		# Replace the new line with a segment separator
#	s/\x2f/\x2a/g;  #Replace "/" field separator with an asterisk (This may be bad if names in the file contain a forward slash!)
	s/\x07/\x2a/g;  #Replace strange field separator with an asterisk
	if (index($_, "KWIBLUE") > 0) {	# Check for KWI 852 data, which is weird!!
		s/\x7c/\x25/g;  #Replace ^ end of line character
		$kwi = 1;
	}
		else {
		s/\x7c/\x2a/g;  #Replace | field separator with an asterisk
		$kwi = 0;
	}
#	s/\x0D//g;
#	s/\x0a//g;
#	s/\x0A//g;
	s/\x15/\x25/g;  #Replace the line separator with something useful
  	s/\x1C/\x25/g;  #Replace strange end of line character
  	s/\x85/\x25/g;  #Replace strange end of line character
  	s/\x3D/\x25/g;  #Replace strange end of line character
  	s/\x7F/\x25/g;  #Replace strange end of line character
  	s/\xA7/\x25/g;  #Replace � end of line character
 	s/\x06/\x25/g;  #Replace � end of line character
  	s/~/\x25/g;  	#Replace tilde end of line character
  	s/\x5E/\x25/g;  #Replace ^ end of line character
  	s/\xB0/\x25/g;  #Replace ^ end of line character
  	s/\xE0/\x25/g;	#Replace � end of line character
  	s/\xC5/\x25/g;	#Replace � end of line character
	s/\x07/\x2A/g;	#Replace  field delimiter with an asterisk
#	s/\x2F/\x2A/g;	#Replace / field delimiter with an asterisk	# 2019.02.27 AR: AAFES Store Names have '/' in their data, as result store numbers are shifted
	s/\x7C/\x2A/g;	#Replace | field delimiter with an asterisk
#	print {OUT3}"$_";	# Used for debugging only
    	#s/PALISADES/Palisades/g;	# Fix the oddest bug in the world.
  	if (index($_, "ISA*", index($_, "ISA*")+1) > 0){	# Looks for the 2nd occurrance of ISA
  		s/ISA\*/~ISA\*/g;   	#Replace the lack of CR for multiple ISA segments in a file
  		$b = -1;		# The line above causes the counter to start at 2, so this fixes that
  	}
  	print "Processing # $filecounter - $file\n";
	#print "$file is /n$_/n/n";
	my @blocks = split /~/;		# Split up the ISA blocks
  	foreach $block (@blocks){
  	  $b ++ ;	#  Counting the blocks
  	  $_ = $block;
	  if ( $block =~ /ST\*852\*/) {
		$filetype = '852';
		@lin_segment; # this variable stores line segment info before outputting
		@za_segment; # this variable stores za segment info before outputting
		$lin_tracker = 0; # this variable tracks if line segment is outputted
		$send_date =0;			# Reset the $send_date variable
		$skip = 0;				# 2016/02/18 fix for not printing items without CTP segment being present.
  	  	print "Block $b is an 852";
		# print (HOLD "$block\n") ;
		# Work on laying out the different records
		my @lines = split /\x25/ , $block ;	# Break up each line in the file
		foreach $line (@lines) {	# Work with each line by checking for the record type
			$j ++ ;		# Count the lines, just for fun
			$line = '*'.$line;	# Put an asterisk at the start of each line to make it easier to break apart
			if ($line =~ /LIN\*/){     #  Remove Boscov's *ONLY string in the LIN record.
				  # print "\nLine is $line \n" ;
					$line =~ s/\*ONLY//g ;
					$line =~ s/\//-/g;		 #  Replace the forward slash "/" with a dash '-'
					# print "After is $line \n";
					}
			my @fields = split /\*/, $line;		# Get each field on the line as delimited by an '*'
			#print "@fields\n";
		# Split the 852 process here to handle KWI vs standard 852 records.
			if ($kwi == 1){
			#print "KWI Data\n"
				if (@fields[1] eq 'ISA'){
					#my $fmt = ">%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%30s%9s\n<";
					#printf $fmt, (@fields);
					printf (OUT "%3s%15s%15s%6s%4s%9s%9d%100s\n", (@fields[1]
						, @fields[7], @fields[9], @fields[10]
						, @fields[11], @fields[14], $fl, $filename));
					#die;
				}
				if ((@fields[1] eq 'GS') && (@fields[4] ne 'INTERCHANGE ID ')) {
					@fields[3]=~ s/^\s+|\s+$//g; 									# 2020.08.24: SB: removed trailing and leading spaces
					if (length(@fields[5]) == 6) {@fields[5] = "20".@fields[5]}	    # 2020.08.21: SB: converted YYMMDD to YYYYMMDD
					printf (OUT "GSA%2s%14s%14s%8s%4s%3s%1s%10s\n", (@fields[2]	#   2019/05/10  SC  Removed the century hard code value.  KWI now uses 8 character date values
					#					printf (OUT "GSA%2s%12s%12s20%8s%4s%3s%1s%10s\n", (@fields[2]	# Added hard coded century value to date element, reduced date element to 6 characters
						, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9]));
						$tpid = @fields[3];
						$send_date = @fields[5];   									# 2020.08.24: SB: Added $send date for KWI_BLUW files for correct archiving
					#die;
				}
				if ((@fields[1] eq 'GS') && (@fields[4] eq 'INTERCHANGE ID ')) {
					if (length(@fields[5]) == 6) {@fields[5] = "20".@fields[5]}	    # 2020.08.21: SB: converted YYMMDD to YYYYMMDD
					printf (OUT "GSA%2s%12sINTERCHANGE %8s%4s%3s%1s%10s\n", (@fields[2]
						, @fields[3], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9]));
						$send_date = @fields[5]; 									# 2020.08.24: SB: Added $send date for KWI_BLUW files for correct archiving
					#die;
				}
				if (@fields[1] eq 'N1') {
					printf(OUT "N1A%2s%5s%2s%7s\n", (@fields[2], @fields[3], @fields[4], @fields[5]));
					$n1_storenum = @fields[5];
				}
				if (@fields[1] eq 'ST') {
					printf (OUT "STA%3s%3s%4s\n", (@fields[2], @fields[3], @fields[4]));
					#die;
				}
				if (@fields[1] eq 'XQ') {
					if (length(@fields[3]) == 6) {@fields[3] = "20".@fields[3]}	    # 2020.08.21: SB: converted YYMMDD to YYYYMMDD
					if (length(@fields[4]) == 6) {@fields[4] = "20".@fields[4]}	    # 2020.08.21: SB: converted YYMMDD to YYYYMMDD
					printf (OUT "XQA%1s%8s%8s\n", (@fields[2], @fields[3], @fields[4]));    #  2019/05/09 - Change date size to 8 bytes on XQA segment for KWI files
						if (@fields[4]){													# we have a week ending date!	Added 2015/09/02 
							$arch_yr = substr(@fields[4],0,4);
							$arch_mo = $arch_yr . '-' . substr(@fields[4],4,2);
							$arch_dt = $arch_mo . '-' . substr(@fields[4],6,2);
							$ending_date = @fields[4];		# This is the week ending date value in the 852
					}
					if (!@fields[4]){		# we have a week ending date only in the start date field!	Added 2015/09/02
						$arch_yr = substr(@fields[3],0,4);
						$arch_mo = $arch_yr . '-' . substr(@fields[3],4,2);
						$arch_dt = $arch_mo . '-' . substr(@fields[3],6,2);
						$ending_date = @fields[3];		# This is the week ending date value in the 852
					}
					#print (" XQA%1s%8s%8s\n" ,(@fields[2], @fields[3], @fields[4])) ;
					#die;
				}
				if (@fields[1] eq 'N9') {
					if (@fields[2] eq 'BT'){
						printf (OUT "N9A%2s%12s\n", (@fields[2], @fields[3]));}
						else {if (@fields[2] eq 'DP'){
							printf (OUT "N9B%2s%12s\n", (@fields[2], @fields[3]));}
							else {if (@fields[2] eq 'IA'){
								printf (OUT "N9C%2s%12s\n", (@fields[2], @fields[3]));}
								 else {printf (OUT "N9X%2s%12s\n", (@fields[2], @fields[3]));}
							}
						}
					#die;
				}
				# if (@fields[1] eq 'LIN') {
				# 	$detail = undef;
				# 	if ($more == 1) {print (OUT "\n")};   # Add a line when needed
				# 	$more = 0;
				# 	@fields[4] =~ s/^00//;
				# 	printf (OUT "LIN%9s%2s%13s\n", (@fields[2], @fields[3], @fields[4]));
				# 	#die;
				# }

				if (@fields[1] eq 'LIN') {
					$detail = undef;
					if ($more == 1) {print (OUT "\n")};   # Add a line when needed
					$more = 0;
					@fields[4] =~ s/^00//;
					$linseq = @fields[2];
					$upctype = @fields[3];
					$upc = @fields[4];
					$styletype = '';		# Set a default value for Style Type
					$style = '';			# Set a default value for Style
					$RES_price = 0.00;		# Set a default value for RES price
					$UCP_price = 0.00;		# Set a default value for UCP price

					# printf (OUT "LIN%9s%2s%13s\n", (@fields[2], @fields[3], @fields[4]));
					#die;

					if (@lin_segment){
						# print lin segment to output
						printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($lin_segment[0], $lin_segment[1], $lin_segment[2], $lin_segment[3], $lin_segment[4], $lin_segment[5], $lin_segment[6]));

						# printing za segments to output
						$len_za_segment = scalar @za_segment; # get length of za segment array
						for ($za_element = 0; $za_element < $len_za_segment; $za_element += 3){
							printf (OUT "ZAA%2sEA92%10s%7s\n",(@za_segment[$za_element],@za_segment[$za_element+1],@za_segment[$za_element+2]));
						}
						@za_segment = ();     # empty za_segment erray after outputting
						@lin_segment = ();    # empty lin_segment erray after outputting

						# push all lin elements to lin_segment array for the present lin
						push(@lin_segment, $linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price);
						
					} elsif (!@lin_segment) {
						# push lin segment info to array
						push(@lin_segment, $linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price);
					}
				}

				if (@fields[1] eq 'ZA') {		# Process detail header. No linefeed, we are adding more to this line
#					if($linprint == 0 ){		# Print the LIN Record with the prices, since it has not yet been printed
#						printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price));
#						$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
#					}
					$detail = 'ZAA'.@fields[2];
					$zarecord = $detail;		# Save the ZA record for re-printing below
					#print (OUT $detail);		# Moved to SDQ Section

					if($tpid eq '001695568GP' || $tpid eq '106514441BJS' || $tpid eq '001695568P' || $tpid eq 'KWIBLUE'){
						# printf (OUT "ZAA%2sEA92%10s%7s\n",(@fields[2],$n1_storenum,@fields[3]));	# Print now for AAFES bacuse they don't send an SDQ
						$za_metric_type = @fields[2];
						$za_units = @fields[3];
						push(@za_segment, $za_metric_type, $n1_storenum, $za_units);
					}
					#die;
				}

				if (@fields[1] eq 'CTP') {		
					if($fields[3] ne 'UCP'){
						$RES_price = $fields[4];	# Set the value found
					}
					if($fields[3] eq 'UCP'){
						$UCP_price = $fields[4];	# Set the value found
					}

					# printf lin segment out with updated prices
					printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price));

					# printing za segments
					$len_za_segment = scalar @za_segment; # get length of za segment array
					for ($za_element = 0; $za_element < $len_za_segment; $za_element += 3){
						printf (OUT "ZAA%2sEA92%10s%7s\n",(@za_segment[$za_element],@za_segment[$za_element+1],@za_segment[$za_element+2]));
					}
					@za_segment = ();     # empty za_segment erray after outputting
					@lin_segment = ();    # empty lin_segment erray after outputting
					#die;
				}

				if (@fields[1] eq 'CTT') {
					# this is the final segment after all LIN segments
					# last LIN segment is still in memory and is not printed
					# this segment prints the last LIN segment to output

					# print lin segment to output
					printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($lin_segment[0], $lin_segment[1], $lin_segment[2], $lin_segment[3], $lin_segment[4], $lin_segment[5], $lin_segment[6]));

					# printing za segments to output
					$len_za_segment = scalar @za_segment; # get length of za segment array
					for ($za_element = 0; $za_element < $len_za_segment; $za_element += 3){
						printf (OUT "ZAA%2sEA92%10s%7s\n",(@za_segment[$za_element],@za_segment[$za_element+1],@za_segment[$za_element+2]));
					}
					@za_segment = ();     # empty za_segment erray after outputting
					@lin_segment = ();    # empty lin_segment erray after outputting
				}

			}	# Here ends the KWI Process
			else {	# Process standard 852 data sources
				if (@fields[1] eq 'ISA'){
					#my $fmt = ">%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%14s%9s\n<";
#					#printf $fmt, (@fields);
#					printf (OUT "%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%1s%30s%9d\n", (@fields[1], @fields[2]
#						, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9], @fields[10]
#						, @fields[11], @fields[12], @fields[13], @fields[14], @fields[15], @fields[16], @fields[17], @fields[18], $name, $fl));
					printf (OUT "%3s%15s%15s%6s%4s%9s%9d%100s\n", (@fields[1]
						, @fields[7], @fields[9], @fields[10]
						, @fields[11], @fields[14], $fl, $filename));
					#die;
				}
				if ((@fields[1] eq 'GS') && (@fields[4] ne 'INTERCHANGE ID ')) {
					printf (OUT "GSA%2s%14s%14s%8s%4s%3s%1s%10s\n", (@fields[2]
						, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9]));
					$tpid = @fields[3];	# This should be the TPID, and we need to check it for special EDI features later
					$send_date = @fields[5];	# Get the send date for the 852 to check for archive directory
					#die;
				}
				if ((@fields[1] eq 'GS') && (@fields[4] eq 'INTERCHANGE ID ')) {
					printf (OUT "GSA%2s%14sINTERCHANG%8s%4s%3s%1s%10s\n", (@fields[2]
						, @fields[3], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9]));
					$tpid = @fields[3];	# This should be the TPID, and we need to check it for special EDI features later
					$send_date = @fields[5];	# Get the send date for the 852 to check for archive directory
					#die;
				}
				if (@fields[1] eq 'ST') {
					printf (OUT "STA%3s%3s%4s\n", (@fields[2], @fields[3], @fields[4]));
					$n1_storenum = undef;	# Reset this value, just in case it persists from prior 852
					#die;
				}
				if (@fields[1] eq 'XQ') {
					printf (OUT "XQA%1s%8s%8s\n", (@fields[2], @fields[3], @fields[4]));
					#die;
					if (@fields[4]){		# we have a week ending date!	Added 2015/09/02
						$arch_yr = substr(@fields[4],0,4);
						$arch_mo = $arch_yr . '-' . substr(@fields[4],4,2);
						$arch_dt = $arch_mo . '-' . substr(@fields[4],6,2);
						$ending_date = @fields[4];		# This is the week ending date value in the 852
            			$xq_end = @fields[4];
						$xq_start = @fields[3];
					}
					if (!@fields[4]){		# we have a week ending date only in the start date field!	Added 2015/09/02
						$arch_yr = substr(@fields[3],0,4);
						$arch_mo = $arch_yr . '-' . substr(@fields[3],4,2);
						$arch_dt = $arch_mo . '-' . substr(@fields[3],6,2);
						$ending_date = @fields[3];		# This is the week ending date value in the 852
					}
				}
				if ((@fields[1] eq 'N1') & (@fields[2] eq 'RL')) {   # There is on an N1 in the AAFES852 & BJS files, it has the store number
					printf(OUT "N1A%2s%40s%2s%7s\n", (@fields[2], @fields[3], @fields[4], @fields[5]));
					$n1_storenum = @fields[5];
				}
				if (@fields[1] eq 'N9') {
					if (@fields[2] eq 'BT'){
						printf (OUT "N9A%2s%12s\n", (@fields[2], @fields[3]));}
					if (@fields[2] eq 'DP'){
						printf (OUT "N9B%2s%12s\n", (@fields[2], @fields[3]));}
					if (@fields[2] eq 'IA'){
						printf (OUT "N9C%2s%12s\n", (@fields[2], @fields[3]));}
					if (@fields[2] eq 'FI'){
						printf (OUT "N9F%2s%12s\n", (@fields[2], @fields[3]));}
					if (@fields[2] ne 'IA' && @fields[2] ne 'DP' && @fields[2] ne 'BT'){
						printf (OUT "N9X%2s%12s\n", (@fields[2], @fields[3]));}
					#die;
				}
				if (@fields[1] eq 'LIN') {
					$l = scalar @fields;		# Get the number of records in this collection (max 10 pairs)
					$detail = undef;
					$price = undef;			# Set the price to undefined, incase it does not exist for this item
					$style = undef ;
					$styletype = undef;
					$upc = undef;
					$upctype = undef;
					$linprint = 0;			# Set the flag for LIN segment printing to 0 (false)
					my $gotupc = 0;			# Flag to stop duplicate LIN record printing for Walmart
					if ($more == 1) {print (OUT "\n")};   # Add a line when needed
					$more = 0;
					for ($k = 3; $k < $l; $k += 2){	# Look through all the item pairs for a UPC code. Ignore all other codes, for now.
					if($fields[$k] eq 'UP' || $fields[$k] eq 'UK' || $fields[$k] eq 'IT' || $fields[$k] eq 'VA' || $fields[$k] eq 'IN' || $fields[$k] eq 'UI' || $fields[$k] eq 'CB' || $fields[$k] eq 'EN') {	# Found something useful!
						@fields[$k+1] =~ s/^00//;
#						$upc = undef;			# Set a default value for UPC
#						$upctype = undef;		# Set a default value for UPC Type
							# printf (OUT "LIN%9s%2s%14s\n", (@fields[2], @fields[$k], @fields[$k+1]));
							if($fields[$k] eq 'UP' || $fields[$k] eq 'UK' || $fields[$k] eq 'UI' || $fields[$k] eq 'EN') {
								$upc = @fields[$k+1];
								$upctype = $fields[$k];
							}
							if($fields[$k] eq 'IT'){
								$style = @fields[$k+1];
								$styletype = 'IT';
							}
							if($fields[$k] eq 'VA'){		# Added to handle Dillards style records
								$style = @fields[$k+1];
								$styletype = 'VA';
							}
							if($fields[$k] eq 'IN'){		# Added to handle Dillards style records
								$style = @fields[$k+1];
								$styletype = 'IN';
							}
							if($fields[$k] eq 'CB'){		# Added to handle Krogers style records
								$style = @fields[$k+1];
								$styletype = 'CB';
							}						}
					if(k > 6){die;}
					}
					@fields[4] =~ s/^00//;
					$linseq = @fields[2];			# Store LIN record sequence number
					# 2015/07/17  Removing the logic to keep the price values for transactions provided without price
					#if($upc != $lastupc){			# This UPC does not match the last one, clear out the price from the CTP record
						$RES_price = 0.00;		# Set a default value for RES price
						$UCP_price = 0.00;		# Set a default value for UCP price
					#}
					$lastupc = $upc;			# Save the current UPC value
					# printf (OUT "LIN%9s%2s%14s%2s%14s\n", (@fields[2], $upctype, $upc, $styletype, $style));	# New print line from Walmart mods. Should work for everyone
					# printf (OUT "LIN%9s%2s%12s\n", (@fields[2], @fields[3], @fields[4]))				# Pre Walmart mods print
					$l = undef;			# Reset this counter
					#  Process this logic only for AAFES & BJ's !
											if(length($style) > 14){
							$style = substr $style, 0,14;    # Added logic to truncate $style values to 14 characters max.  SC
							}  # Truncate the $style value to 14 bytes
					if(($linprint == 0) && ($tpid eq '001695568GP' || $tpid eq '106514441BJS' || $tpid eq '001695568P')){		# Print the LIN Record with the prices, since it has not yet been printed
						printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price));
						$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
					}
					#die;
				}	# After LIN records look for CTP (price) record.  If it exists, we'll combine it with the LIN, otherwise we will not
				if (@fields[1] eq 'CTP') {		# Process Price record, if present; Assuming that if present, it always follows the LIN segment and precedes the ZA Segment
									# Change added to work around bug in WEBFocus
					#print "\nfound; $fields[3]";
					if($fields[3] ne 'UCP'){
						$RES_price = $fields[4];	# Set the value found
					}
					if($fields[3] eq 'UCP'){
						$UCP_price = $fields[4];	# Set the value found
					}
					if($fields[3] eq '' and ($tpid eq '202377222' or $tpid eq '200091189')){	# This is Hudson Bay and it has double the records. Cut one set off.  SC 2015/08/27
						$skip = 1;}
						else {
						$skip = 0;
					}
					#die;
				}
				if (@fields[1] eq 'ZA') {		# Process detail header. No linefeed, we are adding more to this line
#					if($linprint == 0 ){		# Print the LIN Record with the prices, since it has not yet been printed
#						printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price));
#						$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
#					}
					$detail = 'ZAA'.@fields[2];
					$zarecord = $detail;		# Save the ZA record for re-printing below
					#print (OUT $detail);		# Moved to SDQ Section
					if($tpid eq '106514441BJS'){	# Trim all but the last 4 characters of the store number from BJS
						$n1_storenum = substr($n1_storenum, -3);	#	Altered to 3 characters, due to change in the BJS EDI 2016/03021
					}
					if($tpid eq '001695568GP' || $tpid eq '106514441BJS' || $tpid eq '001695568P' ){
						printf (OUT "ZAA%2sEA92%10s%7s\n",(@fields[2],$n1_storenum,@fields[3]));	# Print now for AAFES bacuse they don't send an SDQ
					}
					#die;
				}
				if (@fields[1] eq 'CTT') {	# This is the last record in this group, print the final LIN record
#					if($linprint == 0 ){		# Print the LIN Record with the prices, since it has not yet been printed
#						printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price));
#						$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
#					}
				#die;
				}
				if (@fields[1] eq 'SDQ') {		# Detail record processing.
					$unit = @fields[2];		# Store the value of EA or DO flag
					# Disabled LIN counter! for Belks on line below
#   					if($linprint == 0 ){		# Print the LIN Record with the prices, since it has not yet been printed
						printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price)) unless $skip;
						$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
#					}
					if($more){print(OUT "\n");}	# Add a new line if this is a continuation
#					print(OUT "$zarecord");		# Start a new line and print out the saved header
#					printf(OUT "%2s%2s", (@fields[2], @fields[3])); 	# Print the rest of the record type info
	#				if (! $last_unit eq 'xx'){	# This is not the first time here
					if(! $last_unit == $unit){	# This is probably a DO record, process it as a new record
						print(OUT "$zarecord")  unless $skip;	# Start a new line and print out the saved header (Modified - removed new line
						printf(OUT "%2s%2s", (@fields[2], @fields[3]))  unless $skip; 	# Print the rest of the record type info
					}
	#				}
					$last_unit = $unit;		# Record the current value for the unit
					my $l = scalar @fields;		# Get the number of records in this collection (max 10 pairs)
					#print (OUT "\n\*@fields\*\n");
	# 				if (! $more){
	#					printf(OUT "%2s%2s", (@fields[2], @fields[3]));	# Add the two core fields "UNITS" and the "ID"
	#    				}
	    				$more = 0;
					for ($k = 4; $k < $l; $k +=2){	# Set up a loop to go through the store/units pair values
						if (@fields[$k] > 100000){	# Handles Walmart and other UL (universal store number)
	     						$store = ((@fields[$k] - @fields[$k] % 10)/10) % 10000 ;}
	     					else
	     						{$store = @fields[$k];}
						printf(OUT "%10s%7s", ($store, @fields[$k+1]))  unless $skip;
#					     	$more = 0;  }	# Changed to 0 to fix the problem with continuation after 10 pairs with the ISA record
					     	$store = undef;
					}		# End of For loop
	    				if ($more == 0) {
						print(OUT "\n") unless $skip;		# Add a line feed to the end of the detail record
	    				}
					#die;
				}
				#print (OUT $_);
			}	# End of the Block processing loop
		}
		print " with $j lines.\n";
	}
	else {						# Processing 856 transactions starts here.
		if ( $block =~ /ST\*856\*/) {
		$filetype = '856';
  	  	print "Block $b is an 856";
		# print (HOLD "$block\n") ;
		# Work on laying out the different records
		my @lines = split /\x25/ , $block ;	# Break up each line in the file, incorrect processing of BELK files
		foreach $line (@lines) {		# Work with each line by checking for the record type
			$j ++ ;				# Count the lines, just for fun
			$line = '*'.$line;		# Put an asterisk at the start of each line to make it easier to break apart
			my @fields = split /\*/, $line;	# Get each field on the line as delimited by an '*'
			#print "@fields\n";
			if (@fields[1] eq 'ISA'){
				#my $fmt = ">%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%30s\n<";
				#printf $fmt, (@fields);
#				printf (OUT2 "%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%1s%30s%9d\n", (@fields[1], @fields[2]
#					, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9], @fields[10]
#					, @fields[11], @fields[12], @fields[13], @fields[14], @fields[15], @fields[16], @fields[17], @fields[18], $name, $fl));
				printf (OUT2 "%3s%15s%15s%6s%4s%9s%9d%100s\n", (@fields[1]
					, @fields[7], @fields[9], @fields[10]
					, @fields[11], @fields[14], $fl, $filename));
				#die;
			}
			if (@fields[1] eq 'GS') {
				printf (OUT2 "GSA%2s%14s%14s%8s%4s%5s%1s%10s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9]));
				#die;
			}
			if (@fields[1] eq 'ST') {
				printf (OUT2 "STA%3s%3s%8s\n", (@fields[2], @fields[3], @fields[4]));
				#die;
			}
			if (@fields[1] eq 'BSN') {
				printf (OUT2 "BSN%2s%30s%8s%8s%4s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5], @fields[6]));
					$ship_date = @fields[4];
					if($ship_date < 20010101){		# This value should be a data, but in some files it is all 0s  Make sure the DTM segment will be used instead
						$ship_date = undef;
					}
				#die;
			}

			if ((@fields[1] eq 'HL') & (@fields[4] ne 'I') & (@fields[4] ne 'O') & (@fields[4] ne 'P')) {
					printf (OUT2 "HLA%1s%1s%1s%1s\n", (@fields[2]
						, @fields[3], @fields[4], @fields[5]));
					$tdid = 'TD1';	# Set the proper TD ID for the TD1 Record
					#die;
			}
			if (@fields[1] eq 'TD1') {	# Carrier Details (Quantity and Weight)
							# There are two instances of the TD1 record, one under the HLA and one under HLO
							#  thus the $tpid designator is used to create a TD1 or a TD2 record type for Focus
				if ($tdid ne 'TD1' & $tdid ne 'TD2'){	# In case there is an error, catch it
					$tdid = 'TDX';
				}
				printf (OUT2 "%3s%5s%5s%4s%1s%20s%1s%6s%2s\n", ($tdid, @fields[2]
					, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9]));
				#die;
			}
			if (@fields[1] eq 'TD5') {	# Carrier details (Routing sequence / Transit time)
				printf (OUT2 "TD5%2s%2s%4s%2s%100s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5], @fields[6]));
				#die;
			}
			if (@fields[1] eq 'REF') {	# Shipment reference identification
				if (@fields[2] eq 'BM'){	# BOL Number
				printf (OUT2 "RF2%5s%30s\n", (@fields[2]
					, @fields[3]));}
				if (@fields[2] eq '06'){	# Carrier authorization number
				printf (OUT2 "RF1%5s%30s\n", (@fields[2]
					, @fields[3]));}
				if (@fields[2] eq 'CN'){	# Carrier Reference number
				printf (OUT2 "RF3%5s%30s\n", (@fields[2]
					, @fields[3]));}
				if (@fields[2] eq 'DP'){	# Department number for the order detail (item)
				printf (OUT2 "RF4%5s%30s\n", (@fields[2]
					, @fields[3]));}
				if (@fields[2] eq 'IV'){	# Seller's invoice number
				printf (OUT2 "RF5%5s%30s\n", (@fields[2]
					, @fields[3]));}
#				#die;
			}
			if (@fields[1] eq 'DTM') {
				printf (OUT2 "DTM%3s%8s%4s%2s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5]));
				if(!$ship_date){$ship_date = @fields[3];}
				print "\nShip Date is $ship_date";
				#die;
			}
			if ((@fields[1] eq 'N1') & (@fields[2] eq 'ST')) {
				if (@fields[5] > 100000 and @fields[5] !~ /008965873/){	# Handles Walmart and other UL (universal store number)
	     						$store = ((@fields[5] - @fields[5] % 10)/10) % 10000 ;}
	     					else
	     						{$store = @fields[5];}
				printf (OUT2 "NTS%30s%9s%15s\n", (@fields[3], @fields[4], $store));	# Store Number record for Kmart/Sears Occurs once per file.
			#	printf (OUT2 "N1A%80s%2s%10s\n", (@fields[3]	# Changed the 3rd element to (Store #) to 10 char. string.
			#		, @fields[4], $store));
				#die;
			}
			if ((@fields[1] eq 'N1') & (@fields[2] eq 'SF')) {
				printf (OUT2 "NFA%30s%9s%15s\n", (@fields[3]
					, @fields[4], @fields[5]));
				#die;
			}
			if ((@fields[1] eq 'HL') & (@fields[4] eq 'O')) {
					printf (OUT2 "HLO%8s%8s%1s%8s\n", (@fields[2]
						, @fields[3], @fields[4], @fields[5]));
					$tdid = 'TD2';	# Set the proper TD ID for the TD1 Record
					#die;
			}
			if (@fields[1] eq 'PRF') {
				printf (OUT2 "PRF%15s%2s%2s%8s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5]));
				#die;
			}

			if ((@fields[1] eq 'N1') & (@fields[2] eq 'BY')) {
				printf (OUT2 "\nN1A%80s%2s%14s\n", (@fields[3]	# Changed the 3rd element to (Store #) to 14 char. string.
					, @fields[4], @fields[5]));
				#die;
				}
			if ((@fields[1] eq 'N1') & (@fields[2] eq 'Z7')) {	# JCP Mod
				printf (OUT2 "\nN1A%80s%2s%14s\n", (@fields[3]	# Changed the 3rd element to (Store #) to 14 char. string.
					, @fields[4], @fields[5]));
				#die;
			}
#			if ((@fields[1] eq 'N1') & (@fields[2] eq 'RL')) {
#				printf(OUT2 "N1A%2s%20s%2s%7s\n", (@fields[2], @fields[3], @fields[4], @fields[5]));
#				}
			if ((@fields[1] eq 'HL') & (@fields[4] eq 'P')) {
				printf (OUT2 "HLP%8s%8s%1s%8s", (@fields[2]
					, @fields[3], @fields[4], @fields[5]));
				#die;
			}
			if (@fields[1] eq 'N2') {
				printf (OUT2 "N2A%20s\n", (@fields[2]));
				#die;
			}
			if (@fields[1] eq 'N3') {
				printf (OUT2 "N3A%20s%20s\n", (@fields[2]
					, @fields[3]));
				#die;
			}
			if (@fields[1] eq 'N4') {
				printf (OUT2 "N4A%10s%2s%5s%2s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5]));
				#die;
			}
#			if (@fields[1] eq 'PER') {	# Unnecessary and widely variable segment for information purposes i.e. email
#				printf (OUT2 "PER%2s%20s%2s%11s%2s%30s\n", (@fields[2]
#					, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7]));
#				#die;
#			}
			if (@fields[1] eq 'SN1') {
				printf (OUT2 "SN1%4s%4s%2s\n", (@fields[2]
					, @fields[3], @fields[4]));
				#die;
			}
			if (@fields[1] eq 'PO4') {
				printf (OUT2 "PO4%6s%1s%2s%3s%1s%4s%2s%4s%2s%3s%3s%3s%2s\n", (@fields[2]
					, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9], @fields[10], @fields[11], @fields[12], @fields[13], @fields[14]));
				#die;
			}
			if (@fields[1] eq 'MAN') {	# Marks and numbers - identifiers on the shipping containers
				printf (OUT2 "MAN%2s%20s\n", (@fields[2]
					, @fields[3]));
				#die;
			}
#			if (@fields[1] eq 'CTT') {
#				if($linprint == 0 ){		# Print the LIN Record with the prices, since it has not yet been printed
#					printf (OUT "LIN%9s%2s%14s%2s%14s%7.2f%7.2f\n", ($linseq, $upctype, $upc, $styletype, $style, $RES_price, $UCP_price));
#					$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
#				}
				#die;
#			}
#			if (@fields[1] eq 'SE') {
#				printf (OUT2 "SEA%6.0f%10.0f\n", (@fields[2]
#					, @fields[3]));
#				#die;
#                        }

				if (@fields[1] eq 'LIN') {
					$l = scalar @fields;		# Get the number of records in this collection (max 10 pairs)
					$detail = undef;
					$price = undef;			# Set the price to undefined, incase it does not exist for this item
					$style = undef ;
					$styletype = undef;
					$upc = undef;
					$upctype = undef;
					$linprint = 0;			# Set the flag for LIN segment printing to 0 (false)
					my $gotupc = 0;			# Flag to stop duplicate LIN record printing for Walmart
					if ($more == 1) {print (OUT "\n")};   # Add a line when needed
					$more = 0;
					for ($k = 3; $k < $l; $k += 2){	# Look through all the item pairs for a UPC code. Ignore all other codes, for now.
					if($fields[$k] eq 'EN' || $fields[$k] eq 'UP' || $fields[$k] eq 'UK' || $fields[$k] eq 'IT' || $fields[$k] eq 'VA' || $fields[$k] eq 'IN' || $fields[$k] eq 'UI' || $fields[$k] eq 'CB') {	# Found something useful!
						@fields[$k+1] =~ s/^00//;
#						$upc = undef;			# Set a default value for UPC
#						$upctype = undef;		# Set a default value for UPC Type
							# printf (OUT "LIN%9s%2s%14s\n", (@fields[2], @fields[$k], @fields[$k+1]));
							if($fields[$k] eq 'UP' || $fields[$k] eq 'UK' || $fields[$k] eq 'UI' || $fields[$k] eq 'EN') {
								$upc = @fields[$k+1];
								$upctype = $fields[$k];
							}
							if($fields[$k] eq 'IT'){
								$style = @fields[$k+1];
								$styletype = 'IT';
							}
							if($fields[$k] eq 'VA'){		# Added to handle Dillards style records
								$style = @fields[$k+1];
								# 2015/08/12	SC	Added the 3 lines below to truncate any VA entery longer than 14 bytes.  Problem with GIII 856 for Steinmart.
								if(length($style)>14){
									$style = substr($style,0,14);	# Truncate at 14 bytes.
								}
								$styletype = 'VA';
							}
							if($fields[$k] eq 'IN'){		# Added to handle Dillards style records
								$style = @fields[$k+1];
								$styletype = 'IN';
							}
							if($fields[$k] eq 'CB'){		# Added to handle Krogers style records
								$style = @fields[$k+1];
								$styletype = 'CB';
							}						}
					if(k > 6){die;}
					}
					@fields[4] =~ s/^00//;
					$linseq = @fields[2];			# Store LIN record sequence number
					# printf (OUT "LIN%9s%2s%14s%2s%14s\n", (@fields[2], $upctype, $upc, $styletype, $style));	# New print line from Walmart mods. Should work for everyone
					# printf (OUT "LIN%9s%2s%12s\n", (@fields[2], @fields[3], @fields[4]))				# Pre Walmart mods print
					$l = undef;			# Reset this counter
					#  Process this logic only for AAFES & BJ's !
					if(($linprint == 0) ){		# Print the LIN Record with the prices, since it has not yet been printed
						print length($style);
						if(length($style) > 14){
							$style = substr $style, 0,12;
							}  # Truncate the $style value to 14 bytes
						printf (OUT2 "LIN%9s%2s%14s%2s%14s", ($linseq, $upctype, $upc, $styletype, $style));
						$linprint = 1;		# Set the flag to 1 to prevent duplicate printing of this segment
					}
					#die;
				}	# After LIN records look for CTP (price) record.  If it exists, we'll combine it with the LIN, otherwise we will not

			# if (@fields[1] eq 'LIN') {	# Product item identifier
				# $detail = undef;
				# if ($more == 1) {print (OUT "\n")};   # Add a line when needed
				# $more = 0;
				# @fields[4] =~ s/^00//;
				# printf (OUT2 "LIN%9s%2s%14s%2s%14s", (@fields[2], @fields[3], @fields[4], @fields[5], @fields[6]))
				#die;
			# }
			#  This needs attention!!  The SLN record is not correct, when present (it has no LIN component, and it cannot be attached to the LIN record, as it
			#   repeats any number of times to list the components.  When good, it should have a UPC code value in each record, breaking the the UPC found in the
			#   SN1 record.  Need a working example fromm a client though....
			if (@fields[1] eq 'SLN') {	# Sub-Line item detail (for casepacks). Treat as if it were a standard LIN record to fool the systems
				printf (OUT2 "LIN%9s%2s%14s%2s%14sSN1%4s%4sEA\n", ($blank, @fields[10], @fields[11], @fields[12], @fields[13], @fields[5], @fields[5]))
			}
			if (@fields[1] eq 'CTP') {		# Process Price record, if present
				printf (OUT2 "CTP%6.2f\n", (@fields[4]));
				#die;
			}
#			if (@fields[1] eq 'PO4') {		# Process PO4 record to show content count and type for case/pre-packs
#				printf (OUT2 "PO4%6s%2s\n", (@fields[2], @fields[4]));
				#die;
#			}			}
			if (@fields[1] eq 'ZA') {		# Process detail header. No linefeed, we are adding more to this line
				$detail = 'ZAA'.@fields[2];
				$zarecord = $detail;		# Save the ZA record for re-printing below
				#print (OUT2 $detail);		# Moved to SDQ Section
				#die;
			}
			if (@fields[1] eq 'SDQ') {		# Detail record processing.
				$unit = @fields[2];		# Store the value of EA or DO flag
				if($more){print(OUT2 "\n");}		# Add a new line if this is a continuation
				print(OUT2 "$zarecord");		# Start a new line and print out the saved header
				printf(OUT2 "%2s%2s", (@fields[2], @fields[3])); 	# Print the rest of the record type info
#				if (! $last_unit eq 'xx'){	# This is not the first time here
#					if(! $last_unit == $unit){	# This is probably a DO record, process it as a new record
#						print(OUT2 "\n$zarecord");	# Start a new line and print out the saved header
#						printf(OUT2 "%2s%2s", (@fields[2], @fields[3])); 	# Print the rest of the record type info
#					}
#				}
				$last_unit = $unit;		# Record the current value for the unit
				my $l = scalar @fields;		# Get the number of records in this collection (max 10 pairs)
				#print (OUT2 "\n\*@fields\*\n");
# 				if (! $more){
#					printf(OUT2 "%2s%2s", (@fields[2], @fields[3]));	# Add the two core fields "UNITS" and the "ID"
#    				}
    				$more = 0;
				for ($k = 4; $k < $l; $k +=2){	# Set up a loop to go through the store/units pair values
					printf(OUT2 "%10s%5s", (@fields[$k], @fields[$k+1]));
				     	if ($k == 22){		# Check to see if there is more stores to process
				     		$more = 1;}
	    				if ($more == 0) {
						print(OUT2 "\n");		# Add a line feed to the end of the detail record
	    				}
				#die;
				}
			#print (OUT2 $_);
			}
		}	# End of the Block processing loop
		print " with $j lines.\n";
	}	# End of 856 process
	if ( $block =~ /ST\*846\*/){
		$filetype = '846';
  	  	print "Block $b is an 846";
		# print (HOLD "$block\n") ;
		# Work on laying out the different records
		my @lines = split /\x25/ , $block ;	# Break up each line in the file
		foreach $line (@lines) {	# Work with each line by checking for the record type
			$j ++ ;		# Count the lines, just for fun
			$line = '*'.$line;	# Put an asterisk at the start of each line to make it easier to break apart
			my @fields = split /\*/, $line;		# Get each field on the line as delimited by an '*'
			#print "@fields\n";
				if (@fields[1] eq 'ISA'){
					#my $fmt = ">%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%14s%9s\n<";
					#printf $fmt, (@fields);
					printf (OUT3 "%3s%2s%10s%2s%10s%2s%15s%2s%15s%6s%4s%1s%5s%9s%1s%1s%1s%1s%30s%9d\n", (@fields[1], @fields[2]
						, @fields[3], @fields[4], @fields[5], @fields[6], @fields[7], @fields[8], @fields[9], @fields[10]
						, @fields[11], @fields[12], @fields[13], @fields[14], @fields[15], @fields[16], @fields[17], @fields[18], $name, $fl));
					#die;
				}
				if (@fields[1] eq 'GS') {
					# GS*IB*6113310063*2123541280*20080205*0145*12422*X*004030VICS
					printf (OUT3 "GSA%2s%10s%10s%8s%4s%3s%1s%10s\n", (@fields[2], @fields[3], @fields[4], @fields[5]
						, @fields[6], @fields[7], @fields[8], @fields[9] ));
					#die;
				}
				if (@fields[1] eq 'ST') {
					printf (OUT3 "STA%3s%3s%4s\n", (@fields[2], @fields[3], @fields[4]));
					#die;
				}
				if (@fields[1] eq 'DTM') {
					if (@fields[2] eq '090'){	# Inventory start date
					printf (OUT3 "DTS%3s%8s\n", (@fields[2]
						, @fields[3]));
					}
					if (@fields[2] eq '091'){	# Inventory end date
					printf (OUT3 "DTE%3s%8s\n", (@fields[2]
						, @fields[3]));
					}
				}
				if (@fields[1] eq 'REF') {	# Reference identification
					if (@fields[2] eq 'BT'){	# BOL Number
					printf (OUT3 "RF1%10s%30s\n", (@fields[2]
						, @fields[3]));}
					if (@fields[2] eq 'DP'){	# Department number
					printf (OUT3 "RF1%5s%30s\n", (@fields[2]
						, @fields[3]));}
	#				#die;
				}
				if (@fields[1] eq 'N1') {
					printf(OUT3 "N1A%2s%55s%2s%7s\n", (@fields[2], @fields[3], @fields[4], @fields[5]))
				}
				if (@fields[1] eq 'LIN') {	# Product item identifier
					$detail = undef;
		#				if ($more == 1) {print (OUT "\n")};   # Add a line when needed
					$more = 0;
					@fields[4] =~ s/^00//;
					printf (OUT3 "LIN%9s%2s%14s%2s%14s\n", (@fields[2], @fields[3], @fields[4], @fields[5], @fields[6]))
					#die;
				}
				if (@fields[1] eq 'QTY') {	# Quantity recrod
					printf (OUT3 "QTY%2s%4s\n", (@fields[2], @fields[3],))
				}
		}}
	else {
		select STDOUT;
#		print "Block $b in file $filecounter $file is not an 852, 856 or 846\n";
  		#system "rm $ARGV[0] ";
		#die;
   	}
  	} # End of top loop
	#	print "Test $ARGV[5]\n";
	if($ARGV[5] eq "yes"){	# 2015/09/02 Check the 5th parameter to make sure that we need to archive the data.
	  close $fh unless ! $fh;
		if($filetype eq '852'){			# Handle the archive directory logic to ensure all data for a week is in the same folder
			$done = 0;						# Flag to indicate we generated the correc archive date
			$arch_flag = 1;					# Assume the file will be archived
			$year  = substr $ending_date, 0,4;		# Get year
			$month = substr $ending_date, 4,2;		# Get month
			$day   = substr $ending_date, 6,2;		# Get day
			$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
			print "Ending Date: $year,$month,$day $dow\n";
      if($send_date ne 0){   #extract send_date info if date exists
      $send_year  = substr $send_date, 0,4;		# Get send year
      $send_month = substr $send_date, 4,2;		# Get send month
      $send_day   = substr $send_date, 6,2;		# Get send day
      $send_dow = Day_of_Week($send_year,$send_month,$send_day);	# Find what day of the week is the send date
      print "Send Date: $send_year,$send_month,$send_day $send_dow\n";
    } #end of send_date loop
			if($ending_date > $send_date){			# The ending date is after the sent date, so this is is an inventory file, and needs to be moved back a week
					$Dd = ($dow + 1) *-1;			# Set up the delta to calculate the prior saturday
					($year,$month,$day) = Add_Delta_Days($year,$month,$day,$Dd);
					$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
					if($month < 10 && length($month) == 1){$month = "0".$month;}
					if($day < 10 && length($day) == 1){$day = "0".$day;}
					$arch_yr = $year;
					$arch_mo = $arch_yr . '-' . $month;
					$arch_dt = $arch_mo . '-' . $day;
					print "Date 1: $year,$month,$day $dow\n";
					$done = 1;
			}
			if(! $done && $ending_date < $send_date && $dow == 5){	# This is also a invetory file where the ending date is Friday to show the saturday (Hudson Bay only?)
					($year,$month,$day) = Add_Delta_Days($year,$month,$day,1);
					$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
					if($month < 10  && length($month) == 1){$month = "0".$month;}
					if($day < 10 && length($day) == 1){$day = "0".$day;}
					$arch_yr = $year;
					$arch_mo = $arch_yr . '-' . $month;
					$arch_dt = $arch_mo . '-' . $day;
					print "Date 2: $year,$month,$day $dow\n";
					$done = 1;
			}
			if(! $done && $ending_date < $send_date && $dow == 7){	# This is Tommy Canada (probably). Data is from Monday to Sunday.  We'll archive it with the Saturday preceding
					($year,$month,$day) = Add_Delta_Days($year,$month,$day,-1);
					$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
					if($month < 10  && length($month) == 1){$month = "0".$month;}
					if($day < 10 && length($day) == 1){$day = "0".$day;}
					$arch_yr = $year;
					$arch_mo = $arch_yr . '-' . $month;
					$arch_dt = $arch_mo . '-' . $day;
					print "Date 3: $year,$month,$day $dow\n";
					$done = 1;
			}
			if(! $done && $ending_date < $send_date && $dow == 6){	# This is what it should be
					$day = $day * 1;						# Tunrs it to numeric for correct output
					($year,$month,$day) = Add_Delta_Days($year,$month,$day,0);
					$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
					if($month < 10 && length($month) == 1){$month = "0".$month;}
					if($day < 10 && length($day) == 1){$day = "0".$day;}
					$arch_yr = $year;
					$arch_mo = $arch_yr . '-' . $month;
					$arch_dt = $arch_mo . '-' . $day;
					print "Date 4: $year,$month,$day $dow\n";
					$done = 1;
			}
			if( $dow == 6 && !$done){
					if($month < 10 && length($month) == 1){$month = "0".$month;}
					if($day < 10 && length($day) == 1){$day = "0".$day;}
					$arch_yr = $year;
					$arch_mo = $arch_yr . '-' . $month;
					$arch_dt = $arch_mo . '-' . $day;
					print "Date 5: $year,$month,$day $dow\n";
					$done = 1;
			}
			if(! $done && $ending_date == $send_date && $dow == 7){	# This is Kmart (probably). QA,QC,QP only.  We'll archive it with the Saturday preceding
					($year,$month,$day) = Add_Delta_Days($year,$month,$day,-1);
					$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
					if($month < 10 && length($month) == 1){$month = "0".$month;}
					if($day < 10 && length($day) == 1){$day = "0".$day;}
					$arch_yr = $year;
					$arch_mo = $arch_yr . '-' . $month;
					$arch_dt = $arch_mo . '-' . $day;
					print "Date 6: $year,$month,$day $dow\n";
					$done = 1;
			}
      if(! $done && (($year,$month,$day) = Add_Delta_Days($send_year,$send_month,$send_day,-1)) && ($xq_start == $xq_end)) {	# This is for daily EDI 852 files that we want to move a folder
          $dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
          $daily = '\\Daily';
          ($year,$month,$day) = Add_Delta_Days($year,$month,$day,(6-$dow));  #find the ending_date for the daily file
          if($month < 10  && length($month) == 1){$month = "0".$month;}
          if($day < 10 && length($day) == 1){$day = "0".$day;}
          $arch_yr = $year;
          $arch_mo = $arch_yr . '-' . $month;
          $arch_dt = $arch_mo . '-' . $day;
          print "Date 7: $year,$month,$day $dow\n";
          $done = 1;
      }
      # print "ending_date = ($year,$month,$day), send_date = ($send_year,$send_month,$send_day,-1)\n";
      print "ending_date = $ending_date, send_date = $send_date, dow =$dow\n";
			if(!$done){print "Possbile error: Ending Date: $ending_date is too far from Send Date: $send_date in $filename\n"; 	# This should not happen for an 852
				$arch_flag = 0;			# Set archive flag to false, to leave file in the source folder
				}
		}								# End of 852 Archive process
		if($filetype eq '856'){			# Handle the 856 archive directory logic to ensure all data for a week is in the same folder
				$arch_flag = 1;					# Assume the file will be archived
				$year  = substr $ship_date, 0,4;		# Get year
				$month = substr $ship_date, 4,2;		# Get month
				$day   = substr $ship_date, 6,2;		# Get day
				$dow = Day_of_Week($year,$month,$day);	# Find what day of the week is the ending date
				if($dow == 7){
					$Dd  = 6;			#  Archive is the following Saturday, since the shipment was made on Sunday
				} else {
					$Dd = 6-$dow;		# Archive date is next Saturday
				}
				($year,$month,$day) = Add_Delta_Days($year,$month,$day,$Dd);	# Generate the archive date
				if($month < 10 && length($month) == 1){$month = "0".$month;}
				if(length($day) == 1){$day = "0".$day;}
				$arch_yr = $year;
				$arch_mo = $arch_yr . '-' . $month;
				$arch_dt = $arch_mo . '-' . $day;
				$done = 1;
		}								# End of 856 Archive process
	  print "Final Date: $year,$month,$day $dow\n";
	  $archive = '\\\\449629-file1\X$\\SharedData\\EDI\\' . $arch_yr . '\\' . $arch_mo . '\\' . $arch_dt .'\\' . $filetype . $daily;				# create the archive directory for this file.
    #	Disable in TEST version
    if ($ARGV[6] eq "test"){  # 2019.06.20: SB: Disabled Archiving when running in test
       print "\nParser running in test mode. Archiving disabled\n"
    } else {
	  if(! -d $archive){system "md $archive" ;}		# Production code
	  $move = $ARGV[0]. '\\' .  $filename . ' '. $archive;
	  if ($arch_flag){
		  print "\n$move\n";
		  system "move $move";
	  } else {
		  print "\nFile NOT moved";
		 }
   $daily = undef;
   }   # End of disable archiving file loop for test
	}
}	#end of the File loop.
}
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };
#system "mv $ARGV[0] /home/iadmin/ibi/apps/Backup" ;
select STDOUT;
print "\nProcessed $fc files from $ARGV[0] \nDone.\n";
