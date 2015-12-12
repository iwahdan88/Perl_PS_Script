use strict;
use XML::Simple;
use Data::Dumper;
use warnings;

my $wholeFile = "";								# Global String holding all code lines concatenated
my @lines;										# Array that will hold all file lines as elements
my $FILE_NAME = "";								# Global variable Holding the name of the file currently being processed.
my $Input_line_counter = 0;						# Counts the no of lines inputed to the script (For debugging)
my $Output_line_counter = 0;					# counts the number of the lines out of the script (For debugging)
my ($U8,$S8,$U16,$S16,$U32,$S32);
my $Recursion;
my $Snippits = new XML::Simple;
my $XmlData;
my @SnippitArray;

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 RemoveRedErrors																				 ||
#		Description: This function is used for parsing lines of code that want to be changed						 ||
#					 Along with the replacments from File called "red_errors.pm" and then replace them in the code.	 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub RemoveRedErrors
{
	#Index to loop through Snippits
	my $index = 0;
	#Count indicating the number of replacment in code for each snippit
	my $MatchCount = 0;
	#Holds the Replacment Code per Snippit
	my $ReplacmentCode = "";
	#load all Snippits from XML
	my %SnippitHash = %{$XmlData->{Snippit}};
	# If input argument is == 0
	if(!$_[0])
	{
		# Loop through all snippits
		foreach my $element (keys %SnippitHash)
		{
			# Copy data from XML
			$SnippitArray[$index][0] =  scalar $SnippitHash{$element}->{Original};
			$SnippitArray[$index][1] =  scalar $SnippitHash{$element}->{Replacment};
			$SnippitArray[$index][2] =  scalar $SnippitHash{$element}->{Type};
			$SnippitArray[$index][3] =  scalar $element;
			$SnippitArray[$index][4] =  scalar $SnippitHash{$element}->{File};
			$SnippitArray[$index][5] = 0;
			$index++;
		}
    $index = 0;
	}
	foreach my $Snippit (@SnippitArray)
	{	
		#If the the Current snippit belongs to the current file AND this snippit is not yet replaced in code
		if(($Snippit->[5] == 0) && ($Snippit->[4] eq $FILE_NAME))
		{
			# Replace Code
			$ReplacmentCode = $Snippit->[1] . "  /* " . $Snippit->[2] . " -> " . " Snippit # " . $Snippit->[3] . " */";
			$MatchCount = () = $wholeFile =~ s/\Q$Snippit->[0]\E/$ReplacmentCode/g;
			$SnippitArray[$index][5] = $MatchCount;
		}
		$index++
	}
}
#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 RemoveKeywords																					 ||
#		Description: This function is used for Finding specific KeyWords in the Code and replace or delete them. 	 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub RemoveKeywords
{
	# Removing common code patterns using regex
	$wholeFile =~ s/\_\_attribute\_\_\(\(section\("[^"]*"\)\)\)//g;		# Remove keyword __attribute__
	$wholeFile =~ s/\b_*far\b//g;										# Remove keyword __far
	$wholeFile =~ s/\bnear\b//g;										# Remove keyword near
	$wholeFile =~ s/\b\_+near\b//g;										# Remove keyword __near
	$wholeFile =~ s/\b\@interrupt\b//g;									# Remove @interrupt (replace with nothing)
	$wholeFile =~ s/\b\_\_interrupt\b//g;								# Remove __interrupt
	$wholeFile =~ s/\bsaddr\b//g;										# Remove __io
	$wholeFile =~ s/\b\_\_tiny\b//g;									# Remove __interrupt
	$wholeFile =~ s/\b\_\_stack\b//g;									# Remove __interrupt
	$wholeFile =~ s/\bOS\_INTERNAL\_FUNCTION\b//g;						# Remove OS_INTERNAL_FUNCTION
	$wholeFile =~ s/\@\s*\(0x[0-9A-Fa-f]+\)\;//g;						# Remove assigned address
	$wholeFile =~ s/\b(_*)inline(_*)\b/ /g;
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 ConcatenateFileLines																			 ||
#		Description: This function is used for loading all code lines from STDIN "standard input to the script" 	 ||
#					 and puting it in 1 big string.																 	 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub ConcatenateFileLines
{
	#Flag indicating the current line is the first line in file 
	my $first_flag = 0;
	#Buffer to hold code lines
	my @TempLines;
	#Initialize the global string that will hold all lines in file
	$wholeFile = "";
	open (FILE_DB, 'C:\PVCS-workspace\VSC_CORE_TEAM\07-Process Improvement\16-Polyspace Run\Input.pm')
	or die "Cannot open File_names file" ;
	#Load Lines from inpt stream
	while (my $line = <FILE_DB>)							# As long as there is an input to the script.
	{
		#Trim lines from any leading/trailling spaces or tabs
		$line =~ s/^[ \t]+//g;							# Delete all tabs in line
		$line =~ s/[ \t]+$//g;
		#Catch the file name from first line
		if(!$first_flag)
		{
			$FILE_NAME = $line;							# Detect the file name
			($FILE_NAME) = $FILE_NAME =~ /([a-zA-Z]+\.[cC])/;
			$first_flag = 1;
		}
		#Buffering
		push (@TempLines, $line);
	}
	#Lines concatinated together in 1 string
	$wholeFile = join("",@TempLines);					# Load all lines to 1 big string, each line seperated by th other by "*+*" as a delimiter.
}


#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 GetAssemblyEquivalent																			 ||
#		Description: This function is used for returning an equivilant C code for the passed asm instruction	 	 ||
#		Arguments:	 String VAR.																					 ||
#--------------------------------------------------------------------------------------------------------------------||

sub GetAssemblyEquivalent
{
  my $asm = $_[0];
  if($asm =~ m/\s*jarl\s+_.[^,]*,\s*lp/)
  {
  $asm =~ s/jarl\s+_//g;
	$asm =~ s/,.*/\(\);/g;
	return $asm;
  }
  elsif($asm =~ m/^.[^\(]*\(.[^\)]*\)\s*;\s*/)
  {
    return $asm;
  }
  elsif($asm =~ m/\s*jr\s+_.*/)
  {
	$asm =~ s/jr\s+_//g;
	$asm =~ s/\s*\n/\(\);\n/g;
	return $asm;
  }
  elsif($asm =~ m/\s*jmp\s+_.*/)
  {
	$asm =~ s/jmp\s+_//g;
	$asm =~ s/\s*\n/\(\);\n/g;
	return $asm;
  }
  else
  {
    if(($asm=~m/\n/))
    {
        return " \n";
    }
    else
    {
        return " ";
    }
  }
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 CountPattern																			 		 ||
#		Description: This function is used for returning the number of pattern matches in a string 	 	 			 ||
#		Arguments:	 String VAR1 "String" , String VAR2 "Pattern".													 ||
#--------------------------------------------------------------------------------------------------------------------||

sub CountPattern
{
  my $string = $_[0];
  my $pattern = $_[1];
  my @count = $string =~ /$pattern/g;
  return scalar @count;
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Replace_Asm_Block																			 	 ||
#		Description: This function is used for Removing all Assembly Blocks in the Code and 						 ||
#					 replacing them with equivilant C code	 	 			 										 ||
#		Arguments:	 None.													 										 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Replace_Asm_Block
{
  my $Asm_Flag = 0;  								# Flag to indicate the entrance in an asm block.
  my $Braces_counter = 0;							# Variable holding the difference between open and close braces.
  my @Braces_Open_counter_Array;					# Array to save number of open braces occurence in single line.
  my @Braces_Close_counter_Array;					# Array to save number of close braces occurence in single line.
  foreach my $line (@lines)							# looping through all lines.
  {
    if(!$Asm_Flag)									#Didn't reach asm block yet.
    {
		# Matching "asm" of "__asm" or "asm { or (" or "__asm { or("
		if(($line =~ m/^\/\*.[^\*]*\*\/\s+\_*asm\_*\s*\{?$/) || ($line =~ m/^\_*asm\_*\s*\{?$/))
		{
		  # reached asm block
          $Asm_Flag = 1;		# set Flag
          if ($line =~ m/\{/)	# if first open brace is inline with "asm" keyword
          {
            @Braces_Open_counter_Array = $line =~ m/\{/g;		# count open braces in line.
            @Braces_Close_counter_Array = $line =~ m/\}/g;		# count close braces in line.
			#Load the difference to $Braces_counter
            $Braces_counter = $Braces_counter + scalar @Braces_Open_counter_Array - scalar @Braces_Close_counter_Array;	
			if($Braces_counter == 0)	# Braces balanced?
			{
				$Asm_Flag = 0;			# Reset Flag.
			}
          }
          $line =~ s/.*//g;				# Delete Line.
        
		}
    }
    else # Lines inside the asm block
    {
          @Braces_Open_counter_Array = $line =~ m/\{/g;			
          @Braces_Close_counter_Array = $line =~ m/\}/g;
          $Braces_counter = $Braces_counter + scalar @Braces_Open_counter_Array - scalar @Braces_Close_counter_Array;
            $line =~ s/[\{\}]+//g;
			      $line = GetAssemblyEquivalent($line);
          if($Braces_counter == 0)
          {
              $Asm_Flag = 0;
          }
    }
  }
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 RemoveAssemblyFunctions																		 ||
#		Description: This function is used for Removing all Assembly Functions in the Code and 						 ||
#					 replacing them with equivilant C code	 	 			 										 ||
#		Arguments:	 None.													 										 ||
#--------------------------------------------------------------------------------------------------------------------||

sub RemoveAssemblyFunctions
{	

  my $inAssembly = 0;
  my $open = 0;
  my $begun = 0;
  my $returnvalue = "";
  my $returntype = 1;
	foreach my $line (@lines)
	{  
		my $returntype = 1;
      # detecting an openning assembly function block
      if ($inAssembly == 0 && $line =~ m/\basm(?!\s*:)\b\s+.[^\(]*\((.[^\)]*)?\)/)
      {
	  # Generate a return value of type corresponding to the return type of the function.
        if ($line =~ m/\s*ULONG\s+/)
        {
			$returnvalue = "volatile unsigned long x; unsigned long y = x; return y; ";
        }
        elsif ($line =~ m/\s*SLONG\s+/)
        {
			$returnvalue = "volatile signed long x; signed long y = x; return y; ";
        }
        elsif ($line =~ m/\s*USHORT\s+/)
        {
			$returnvalue = "volatile unsigned short x; unsigned short y = x; return y; ";
        }
        elsif ($line =~ m/\s*SSHORT\s+/)
        {
			$returnvalue = "volatile signed short x; signed short y = x; return y; ";
        }
        elsif ($line =~ m/\s*UCHAR\s+/)
        {
		$returnvalue = "volatile unsigned char x; unsigned char y = x; return y; ";
        }
        elsif ($line =~ m/\s*SCHAR\s+/)
        {
			$returnvalue = "volatile signed char x; signed char y = x; return y; ";
        }
        else
        {
          $returntype = 0;
        }
        #set in assembly flag
        $inAssembly = 1;
        
        # add open paranthesis count
        $open += CountPattern($line,"\{");
        
        # set begun flag which means that the first paranthesis is openned
        if($open > 0)
        {
          $begun = 1; 
        }              
        # remove the asm keyword
        $line =~ s/\s?asm\s/ /g;
        
      }
      elsif($inAssembly == 1)
      {
        
        
        # if this line is not an openning or closing paranthesis
        if(CountPattern($line,"\{") == 0 && CountPattern($line,"\}") == 0)
        {
          # check if inside
          if($begun == 1)
          {
			# replace assembly code with equivalent C code
				
				$line = GetAssemblyEquivalent($line);
          }
        }
        
        # increment open
        $open += CountPattern($line,"\{");
        
        # set begun flag which means that the first paranthesis is openned
        if($open > 0)
        {
          $begun = 1;
        }
        # decrement open
        $open -= CountPattern($line,"\}");
        # check for end of block
        if($begun == 1 && $open == 0)
        {
          # unset inassembly flag
          $inAssembly = 0;
          # unset the begun flag
          $begun = 0;
		  if($returntype)
		  {
			$line = $returnvalue.$line;
		  }
        } 
      }
	}
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Remove_Pragma_Asm																			 	 ||
#		Description: This function is used for replacing #pragma asm block											 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Remove_Pragma_Asm
{
  my $Asm_flag = 0;									# Flag to indicate the presence of #pragma asm block
  my $first_func_flag = 0;
  my $Contains_func = 0;
  foreach my $line (@lines)							# Loop through all lines
  {
    if(!$Asm_flag)									# Didn't Reach Block yet
    {
      if($line =~ m/\#\s*pragma\s+asm/)
      {
        $Asm_flag = 1;								# Reached,  set flag
        $line =~ s/.*//g;							# delete line.
      }
    }
    else											# Inside the block
    {
      if($line =~ m/\#\s*pragma(?=\s+endasm)/)	# check Block End
      {
        $Asm_flag = 0;								# Reset Flag.
        $line =~ s/.*//g;							# Delete line.
    	if($Contains_func)
    	{
    		$line =~ s/.*/}/;
    	}
    	$first_func_flag = 0;
    	$Contains_func = 0;
      }
      else
      {
        $line = GetAssemblyEquivalent($line);		# Get the equivilant C code.
		if(($line =~ m/\{/) && !$first_func_flag)
        {
		      $first_func_flag = 1;
		      $Contains_func = 1;
        }
        elsif(($line =~ m/\{/) && $first_func_flag)
        {
          $line = "}".$line;
        }
		else
		{
			# Do Nothing
		}
      }
    }
  }
}
#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Remove_asm_func_call																		 	 ||
#		Description: This function is used for Removing the asm("") case and asm :									 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Remove_asm_func_call
{
	my $Asm_flag = 0;											# Reset flag
	my $first_func_flag = 0;
	my $Contains_func = 0;
	my $file_lines = 0;
	my $remaining_braces = "";
 	my $temp_line = "";
  	my $asmEqiv = "";
	foreach my $line (@lines)									# loop through all lines
	{
		$file_lines ++;
		if($Asm_flag)											# flag is raised, next line
		{
			if($line =~ m/^\s*\w/)
			{
				$line = GetAssemblyEquivalent($line);			# get C equivelant
				if(($line =~ m/\{/) && !$first_func_flag)
				{
					$first_func_flag = 1;
					$Contains_func ++;
				}
				elsif(($line =~ m/\{/) && $first_func_flag)
				{
					$line = "}".$line;
				}
				else
				{
					# Do Nothing
				}
				$Asm_flag = 0;									# reset flag
			}
			else
			{
				# Do nothing
			}
		}
		elsif($line =~ m/\b\s*(_*)asm(_*)\s*\(.[^;]*;/)			# if asm ("") case found
		{
			($temp_line) = $line =~ /((_*)asm(_*)\s*\(.[^\)]*\);)/;				# get what is inside the brackets only
			($asmEqiv) = $temp_line =~ /\(\s*\"(.[^\"]*)\"\s*\);/;
			$asmEqiv = GetAssemblyEquivalent($asmEqiv);				# get it's C equivelant
      		$line =~ s/\Q$temp_line\E/$asmEqiv/;
		}
		elsif($line =~ m/^\s*asm\s*:\n*/)						# found asm: case
		{
			if($line =~ m/^\s*asm\s*:.*\n/)
			{
				$line =~ s/\s*asm\s*:\s*/\n/g;					# Asm instr is in the next line
				$Asm_flag =1;									# raise flag
			}
			else
			{
				$line =~ s/\s*asm\s*://g;						# Asm instr is in the same line
				$line = GetAssemblyEquivalent($line);			# Get C equivelant
				if(($line =~ m/\{/) && !$first_func_flag)
				{
					$first_func_flag = 1;
					$Contains_func ++;
				}
				elsif(($line =~ m/\{/) && $first_func_flag)
				{
					$line = "}".$line;
				}
				else
				{
					# Do Nothing
				}
			}
		}
	}
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Remove_pragma_Asm_line																		 	 ||
#		Description: This function is used for Removing the # pragma lines except #pragma asm / #pragma endasm		 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Remove_pragma_Asm_line
{
	foreach my $line (@lines)
	{
		if($line =~ m/^\s*#\s*pragma(?!\s+(asm|endasm))\s+.[^\*\/]*$/)
		{
			$line =~ s/.*//g;
		}
		elsif($line =~ m/^\s*\/\*\s*#\s*pragma(?!\s+(asm|endasm))\s+.*/)
		{
			$line =~ s/\/\*.[^\*\/]*/\/\*\n/g;
		}
		elsif($line =~ m/^\s*#\s*pragma(?!\s+(asm|endasm))\s+.[^\*\/]*\*\//)
		{
			$line =~ s/.[^\*\/]*\*\//\*\//g;
		}
	}
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Replace_Casting_overflows_unsigned																 ||
#		Description: This function is used for working around casted constant unsigned overflows					 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||
sub Replace_Casting_overflows_unsigned
{
  my (@OverFlows, @OverFlow_types);
  my @temp_OVFL;
  my $pat_neg = '\-\s*[0-9]+';
  my $pat_neg_2 = '\(\s*\-\s*[0-9]+\s*\)';
  my $pat_pos = '[1-9][0-9]+';
  my $pat_pos_2 = '\(\s*[1-9][0-9]+\s*\)';
  my $pat_U8 = '0x[0-9ABCDEFabcdef]{3,}';
  my $pat_U8_br = '\(\s*0x[0-9ABCDEFabcdef]{3,}\s*\)';
  my $pat_U16 = '0x[0-9ABCDEFabcdef]{5,}';
  my $pat_U16_br = '\(\s*0x[0-9ABCDEFabcdef]{5,}\s*\)';
  my $pat_U32 = '0x[0-9ABCDEFabcdef]{9,}';
  my $pat_U32_br = '\(\s*0x[0-9ABCDEFabcdef]{9,}\s*\)';
	my $pattern_U8 = qr/$pat_U8/;
  my $pattern_U8_br = qr/$pat_U8_br/;
  my $pattern_U16 = qr/$pat_U16/;
  my $pattern_U16_br = qr/$pat_U16_br/;
  my $pattern_U32 = qr/$pat_U32/;
  my $pattern_U32_br = qr/$pat_U32_br/;
	my $pattern_neg = qr/$pat_neg/;
  my $pattern_neg_2 = qr/$pat_neg_2/;
  my $pattern_pos = qr/$pat_pos/;
  my $pattern_pos_2 = qr/$pat_pos_2/;
  my $pattern_typ_U8 = qr/$U8/;
  my $pattern_typ_U16 = qr/$U16/;
  my $pattern_typ_U32 = qr/$U32/;
  my $i;
	@temp_OVFL = $wholeFile =~ /((?<!sizeof)\(\s*(?:$pattern_typ_U8)\s*\)\s*(?:$pattern_neg|$pattern_neg_2|$pattern_pos|$pattern_pos_2|$pattern_U8|$pattern_U8_br))/g;
  for($i =0;$i <scalar @temp_OVFL;$i++)
  {
    push(@OverFlow_types, 0);
  }
	push(@OverFlows,@temp_OVFL);
	@temp_OVFL = ();
  @temp_OVFL = $wholeFile =~ /((?<!sizeof)\(\s*(?:$pattern_typ_U16)\s*\)\s*(?:$pattern_neg|$pattern_neg_2|$pattern_pos|$pattern_pos_2|$pattern_U16|$pattern_U16_br))/g;
  for($i =0;$i <scalar @temp_OVFL;$i++)
  {
    push(@OverFlow_types, 1);
  }
  push(@OverFlows,@temp_OVFL);
	@temp_OVFL = ();
  @temp_OVFL = $wholeFile =~ /((?<!sizeof)\(\s*(?:$pattern_typ_U32)\s*\)\s*(?:$pattern_neg|$pattern_neg_2|$pattern_pos|$pattern_pos_2|$pattern_U32|$pattern_U32_br))/g;
  for($i =0;$i <scalar @temp_OVFL;$i++)
  {
    push(@OverFlow_types, 2);
  }
  push(@OverFlows,@temp_OVFL);
	@temp_OVFL = ();
	my $replacment;
	my $temp;
 # my $temp_2;
	my @count_temp;
	my $number;
  my $prev_error = "";
  my $Loop_counter = -1;
  my $No_of_hex_digits;
  my $Max_type_limit;
  my $Hex_number;
	foreach my $Error (@OverFlows)
	{
    $Loop_counter++;
    next if $prev_error =~ m/\Q$Error\E/;
    if($OverFlow_types[$Loop_counter] == 0)
    {
      $No_of_hex_digits = 2;
      $Max_type_limit = 255;
      $Hex_number = "0xFF";
    }
    elsif($OverFlow_types[$Loop_counter] == 1)
    {
      $No_of_hex_digits = 4;
      $Max_type_limit = 65535;
      $Hex_number = "0xFFFF";
    }
    elsif($OverFlow_types[$Loop_counter] == 2)
    {
      $No_of_hex_digits = 8;
      $Max_type_limit = 4294967295;
      $Hex_number = "0xFFFFFFFF";
    }
    else
    {
      # Error
    }
		if($Error =~ m/0x[0-9ABCDEFabcdef]+/)
		{
			$replacment = $Error;
			($temp) = $Error =~ /0x([0-9ABCDEFabcdef]+)/;
			@count_temp = $temp =~ /[0-9ABCDEFabcdef]/g;
			$number = scalar @count_temp - $No_of_hex_digits;
			$replacment =~ s/0x[0-9ABCDEFabcdef]{\Q$number\E}/0x/;
			$wholeFile =~ s/\Q$Error\E/$replacment/;
			@count_temp = ();
		}
		if($Error =~ m/\(.[^\)]*\)\s*\(?\s*\-?\s*[0-9]+\s*\)?/)
		{
			$replacment = $Error;
      if($Error =~ m/\-/)
      {
			  ($temp) = $Error =~ /\-\s*([0-9]+)/;
			  $temp = scalar $temp - 1;
        while ($temp > $Max_type_limit)
        {
          $temp = scalar $temp - $Max_type_limit - 1;
        }
        $number = $Max_type_limit -$temp;
			  $replacment =~ s/\-\s*[0-9]+/$number/;
      }
      else
      {
        ($temp) = $Error =~ /\)\s*([0-9]+)/;
        while($temp > $Max_type_limit)
        {
          $temp = scalar $temp -$Max_type_limit - 1;
        }
        $replacment =~ s/[0-9]+$/$temp/;
      }
			$wholeFile =~ s/\Q$Error\E/$replacment/g;
		}
    else{}#Do Nothing
    $prev_error = $Error;
	}
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Replace_Casting_overflows_signed																 ||
#		Description: This function is used for working around casted constant signed overflows						 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Replace_Casting_overflows_signed
{
  my (@OverFlows, @OverFlow_types);
  my @temp_OVFL;
  my $pat_hex_S8 = '0x[8-9ABCDEFabcdef][0-9ABCDEFabcdef]+';
  my $pat_hex_S8_2 = '0x[0-9ABCDEFabcdef]{3,}';
  my $pat_hex_S8_br = '\(\s*0x[8-9ABCDEFabcdef][0-9ABCDEFabcdef]\s*\)';
  my $pat_hex_S8_2_br = '\(\s*0x[0-9ABCDEFabcdef]{3,}\s*\)';
  my $pat_hex_S16 = '0x[8-9ABCDEFabcdef][0-9ABCDEFabcdef]{3}';
  my $pat_hex_S16_2 = '0x[0-9ABCDEFabcdef]{5,}';
  my $pat_hex_S16_br = '\(\s*0x[8-9ABCDEFabcdef][0-9ABCDEFabcdef]{3}\s*\)';
  my $pat_hex_S16_2_br = '\(\s*0x[0-9ABCDEFabcdef]{5,}\s*\)';
  my $pat_hex_S32 = '0x[8-9ABCDEFabcdef][0-9ABCDEFabcdef]{7}';
  my $pat_hex_S32_2 = '0x[0-9ABCDEFabcdef]{9,}';
  my $pat_hex_S32_br = '\(\s*0x[8-9ABCDEFabcdef][0-9ABCDEFabcdef]{7}\s*\)';
  my $pat_hex_S32_2_br = '\(\s*0x[0-9ABCDEFabcdef]{9,}\s*\)';
  my $pat_neg = '\-\s*[1-9][0-9]+(?![xX])';
  my $pat_pos = '[1-9][0-9]+';
  my $pat_neg_br = '\(\s*\-\s*[1-9][0-9]+\s*\)';
  my $pat_pos_br = '\(\s*[1-9][0-9]+\s*\)';
  my $Pattern_hex_S8 = qr/$pat_hex_S8/;
  my $Pattern_hex_S8_2 = qr/$pat_hex_S8_2/;
  my $Pattern_hex_S8_br = qr/$pat_hex_S8_br/;
  my $Pattern_hex_S8_2_br = qr/$pat_hex_S8_2_br/;
  my $Pattern_hex_S16 = qr/$pat_hex_S16/;
  my $Pattern_hex_S16_2 = qr/$pat_hex_S16_2/;
  my $Pattern_hex_S16_br = qr/$pat_hex_S16_br/;
  my $Pattern_hex_S16_2_br = qr/$pat_hex_S16_2_br/;
  my $Pattern_hex_S32 = qr/$pat_hex_S32/;
  my $Pattern_hex_S32_2 = qr/$pat_hex_S32_2/;
  my $Pattern_hex_S32_br = qr/$pat_hex_S32_br/;
  my $Pattern_hex_S32_2_br = qr/$pat_hex_S32_2_br/;
  my $Pattern_neg = qr/$pat_neg/;
  my $Pattern_pos = qr/$pat_pos/;
  my $Pattern_neg_br = qr/$pat_neg_br/;
  my $Pattern_pos_br = qr/$pat_pos_br/;
  my $pattern_typ_S8 = qr/$S8/;
  my $pattern_typ_S16 = qr/$S16/;
  my $pattern_typ_S32 = qr/$S32/;

	@temp_OVFL = $wholeFile =~ /((?<!sizeof)\(\s*(?:$pattern_typ_S8)\s*\)\s*(?:$Pattern_hex_S8|$Pattern_hex_S8_2|$Pattern_hex_S8_br|$Pattern_hex_S8_2_br|$Pattern_neg|$Pattern_neg_br|$Pattern_pos|$Pattern_pos_br))/g;
  for(my $i =0;$i <scalar @temp_OVFL;$i++)
  {
    push(@OverFlow_types, 0);
  }
	push(@OverFlows,@temp_OVFL);
	@temp_OVFL = ();
	@temp_OVFL = $wholeFile =~ /((?<!sizeof)\(\s*(?:$pattern_typ_S16)\s*\)\s*(?:$Pattern_hex_S16|$Pattern_hex_S16_2|$Pattern_hex_S16_br|$Pattern_hex_S16_2_br|$Pattern_neg|$Pattern_neg_br|$Pattern_pos|$Pattern_pos_br))/g;
  for(my $a =0;$a <scalar @temp_OVFL;$a++)
  {
    push(@OverFlow_types, 1);
  }
	push(@OverFlows,@temp_OVFL);
	@temp_OVFL = ();
	@temp_OVFL = $wholeFile =~ /((?<!sizeof)\(\s*(?:$pattern_typ_S32)\s*\)\s*(?:$Pattern_hex_S32|$Pattern_hex_S32_2|$Pattern_hex_S32_br|$Pattern_hex_S32_2_br|$Pattern_neg|$Pattern_neg_br|$Pattern_pos|$Pattern_pos_br))/g;
  for(my $c =0;$c <scalar @temp_OVFL;$c++)
  {
    push(@OverFlow_types, 2);
  }
	push(@OverFlows,@temp_OVFL);
	@temp_OVFL = ();
  my $replacment;
  my $temp;
  my $temp_2;
	my @count_temp;
	my $number;
  my $prev_error = "";
  my $Loop_counter = -1;
  my $No_of_hex_digits;
  my $Max_type_limit_pos;
  my $Max_type_limit_neg;
  my $Hex_number;
  my $remaining_digits;
	foreach my $Error (@OverFlows)
	{
    $Loop_counter++;
    next if $prev_error eq $Error;
    if($OverFlow_types[$Loop_counter] == 0)
    {
      $No_of_hex_digits = 2;
      $Max_type_limit_pos = 127;
      $Max_type_limit_neg = -128;
      $Hex_number = "0xFF";
    }
    elsif($OverFlow_types[$Loop_counter] == 1)
    {
      $No_of_hex_digits = 4;
      $Max_type_limit_pos = 32767;
      $Max_type_limit_neg = -32768;
      $Hex_number = "0xFFFF";
    }
    elsif($OverFlow_types[$Loop_counter] == 2)
    {
      $No_of_hex_digits = 8;
      $Max_type_limit_pos = 2147483647;
      $Max_type_limit_neg = -2147483648;
      $Hex_number = "0xFFFFFFFF";
    }
    else
    {
      # Error
    }
		if($Error =~ m/0x[0-9ABCDEFabcdef]+/)
		{
      $replacment = $Error;
      $remaining_digits = $No_of_hex_digits +1;
      if($Error =~ m/0x[0-9ABCDEFabcdef]{\Q$remaining_digits\E,}/)
      {
    	  ($temp) = $Error =~ /0x([0-9ABCDEFabcdef]+)/;
			  @count_temp = $temp =~ /[0-9ABCDEFabcdef]/g;
			  $number = scalar @count_temp - $No_of_hex_digits;
			  $replacment =~ s/0x[0-9ABCDEFabcdef]{\Q$number\E}/0x/;
        if($replacment =~ m/0x[8-9ABCDEFabcdef]/)
        {
          ($temp) = $replacment =~ /(0x[0-9ABCDEFabcdef]+)/;
          $temp_2 = hex($temp);
          $number = $Max_type_limit_neg + ($temp_2 - $Max_type_limit_pos -1);
          $replacment =~ s/0x[0-9ABCDEFabcdef]+/$number/;
        }
			  @count_temp = ();
      }
      else
      {
        ($temp) = $Error =~ /(0x[0-9ABCDEFabcdef]+)/;
        $temp = hex ($temp);
        $temp_2 = $temp - $Max_type_limit_pos -1;
        $number = $Max_type_limit_neg + $temp_2;
        $replacment =~ s/0x[0-9ABCDEFabcdef]+/$number/;
      }
      $wholeFile =~ s/\Q$Error\E/$replacment/g;
		}
		elsif($Error =~ m/($Pattern_neg|$Pattern_pos|$Pattern_neg_br|$Pattern_pos_br)/)
		{
      $replacment = $Error;
			if($Error =~ m/\-/)
      {
  		  ($temp) = $Error =~ /(\-\s*[0-9]+)/;
        while ($temp < $Max_type_limit_neg)
        {
          $temp = $Max_type_limit_pos - ($Max_type_limit_neg - $temp -1);
        }
        $replacment =~ s/\-\s*[0-9]+/$temp/;
      }
      else
      {
        ($temp) = $Error =~ /\(.[^\)]*\)\s*\(?([0-9]+)/;
        while($temp > $Max_type_limit_pos)
        {
          $temp = $Max_type_limit_neg + ($temp - $Max_type_limit_pos -1);
        }
        $replacment =~ s/[0-9]{3,}/$temp/;
      }
			$wholeFile =~ s/\Q$Error\E/$replacment/g;
		}
    else
    {
      # Do Nothing
    }
    $prev_error = $Error;
	}
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Replace_neg_general																			 ||
#		Description: This function is used for Replacing the "~" operator with workaround 							 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Replace_neg_general
{
  my @neg_counter;
  my $count =0;
  my $temp;
  my $length;
  my $pattern_typ_U8 = qr/$U8/;
  my $pattern_typ_U16 = qr/$U16/;
  my $pattern_typ_U32 = qr/$U32/;
  foreach my $line (@lines)
  {
	if($line =~ m/\bif|\bwhile|\bfor|\belseif/)
	{
		# Skip
	}
	else
	{
		@neg_counter = $line =~ m/\~/g;
		while ((scalar @neg_counter) > 0)
		{
			$count ++;
			if($line =~ m/\(\s*($pattern_typ_U32)\)\s*\~(?!\s*0x)/)
			{
				$line =~ s/\~/(\/*neg*\/0xFFFFFFFF) - /g;
			}
			elsif ($line =~ m/\(\s*($pattern_typ_U16)\s*\)\s*\~(?!\s*0x)/)
			{
				$line =~ s/\~/(\/*neg*\/0xFFFFFFFF) - /g;
			}
			elsif ($line =~ m/\(\s*($pattern_typ_U8)\s*\)\s*\~(?!\s*0x)/)
			{
				$line =~ s/\~/(\/*neg*\/0xFFFFFFFF) - /g;
			}
			elsif ($line =~ m/\(\s*($pattern_typ_U8)\s*\)\s*\(+\~(?!\s*0x)/)
			{
				$line =~ s/\~/0xFFFFFFFF -/g;
			}
			elsif ($line =~ m/\(\s*($pattern_typ_U16)\s*\)\s*\(+\~(?!\s*0x)/)
			{
				$line =~ s/\~/0xFFFFFFFF -/g;
			}
			elsif ($line =~ m/\(\s*($pattern_typ_U32)\s*\)\s*\(+\~(?!\s*0x)/)
			{
				$line =~ s/\~/0xFFFFFFFF -/g;
			}
			elsif($line =~ m/\~\s*0x[ABCDEFabcdef0-9]+/)
			{
			  ($temp) = $line =~ /\~\s*0x([ABCDEFabcdef0-9]+)/;
			  $length = length($temp);
			  if($length == 2)
			  {
				$line =~ s/\~/0xFF - /g;
			  }
			  elsif($length == 4)
			  {
				$line =~ s/\~/0xFFFF - /g;
			  }
			  elsif($length == 8)
			  {
				$line =~ s/\~/0xFFFFFFFF - /g;
			  }
			  else
			  {
				@neg_counter = ();
			  }
			}
			else
			{
				@neg_counter = ();
			}
		}
	}
  }
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Scan_Data_Types																				 ||
#		Description: This function is used for scanning the size of all types in the file							 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Scan_Data_Types
{
  my @Std_Types = ("uint8", "uint16", "uint32", "sint8", "sint16", "sint32", "UCHAR", "USHORT", "ULONG", "SCHAR", "SSHORT", "SLONG", "unsigned char", "unsigned short", "unsigned long", "signed char", "signed short", "signed long", "unsigned int", "signed int"
  , "unsigned   char", "unsigned   short", "unsigned   long", "signed   char", "signed   short", "signed   long", "unsigned   int", "signed   int");
  my @loc_U8 = ("uint8", "UCHAR", "unsigned char");
  my @loc_S8 = ("sint8", "SCHAR", "signed char");
  my @loc_U16 = ("uint16","USHORT", "unsigned short");
  my @loc_S16 = ("sint16", "SSHORT", "signed short");
  my @loc_U32 = ("uint32", "ULONG", "unsigned long", "unsigned int");
  my @loc_S32 = ("sint32", "SLONG", "signed long", "signed int");
  my (@Interm_Map,@Type_Map);
  my ($Type,$Mask, $temp1,$temp2);
  my $Type_found_flag;
  my $temp_line = "";
  foreach my $line (@lines)
  {
    $Type_found_flag = 0;
    if($line =~ m/^\s*typedef\s+.[^;]*;/)
    {
    $temp_line = $line;
    $temp_line =~ s/;.*/;/;
		next if(($temp_line =~m/\*/) || ($temp_line =~m/struct|union|enum|void|\(|\)/));
      ($Type) = $line =~ /typedef\s+(.[^;]*\s*;)/;
      ($Mask) = $Type =~ /(.[^\s;]*)\s*;/;
      $Mask =~ s/\s*;$//;
      $Mask =~ s/^\s*//;
      $Type =~ s/.[^\s;]*\s*;//;
      $Type =~ s/^\s*//g;
      $Type =~ s/\s*$//g;
      foreach my $stdtype (@Std_Types)
      {
        if($stdtype eq $Type)
        {
          $Mask = $Mask."\@$Type";
          push(@Type_Map, $Mask);
          $Type_found_flag = 1;
          last;
        }
      }
      if(!$Type_found_flag)
      {
        $Mask = $Mask."\@$Type";
        push(@Interm_Map, $Mask);
      }
    }
    else
    {
      #Do Nothing
    }
  }
  while (scalar @Interm_Map > 0)
  {
    for (my $i = 0;$i<scalar @Interm_Map;$i++)
    {
      ($temp1) = $Interm_Map[$i] =~ /\@(.*)/;
      for (my $j = 0;$j<scalar @Type_Map;$j++)
      {
        ($temp2) = $Type_Map[$j] =~ /(.[^\@]*)\@/;
        if($temp1 eq $temp2)
        {
          ($Type) = $Type_Map[$j] =~ /\@(.*)/;
          ($Mask) = $Interm_Map[$i] =~ /(.[^\@]*)\@/;
          $Mask = $Mask."\@$Type";
          push(@Type_Map, $Mask);
          last;
        }
      }
	  splice (@Interm_Map, $i, 1);
    }
  }
  foreach my $typemap (@Type_Map)
  {
    ($temp1) = $typemap =~ /\@(.*)/;
    ($temp2) = $typemap =~ /(.[^\@]*)\@/;
    #$temp2 =~ s/^\s//g;
    for (my $k = 0;$k<4;$k++)
    {
      if($k<3)
      {
        if($temp1 eq $loc_U8[$k])
        {
          $U8 = $U8."$temp2|";
          last;
        }
        elsif($temp1 eq $loc_U16[$k])
        {
          $U16 = $U16."$temp2|";
          last;
        }
        elsif($temp1 eq $loc_S8[$k])
        {
          $S8 = $S8."$temp2|";
          last;
        }
        elsif($temp1 eq $loc_S16[$k])
        {
          $S16 = $S16."$temp2|";
          last;
        }
		elsif($temp1 eq $loc_U32[$k])
        {
          $U32 = $U32."$temp2|";
          last;
        }
        elsif($temp1 eq $loc_S32[$k])
        {
          $S32 = $S32."$temp2|";
          last;
        }
      }
      else
      {
        if($temp1 eq $loc_U32[$k])
        {
          $U32 = $U32."$temp2|";
          last;
        }
        elsif($temp1 eq $loc_S32[$k])
        {
          $S32 = $S32."$temp2|";
          last;
        }
      }
    }
  }
  $U8 =~ tr/\|$//;
  $U8 =~ tr/[\(\)\*]//;
  $S8 =~ tr/\|$//;
  $S8 =~ tr/[\(\)\*]+//;
  $U16 =~ tr/\|$//;
  $U16 =~ tr/[\(\)\*]+//;
  $S16 =~ tr/\|$//;
  $S16 =~ tr/[\(\)\*]+//;
  $U32 =~ tr/\|$//;
  $U32 =~ tr/[\(\)\*]+//;
  $S32 =~ tr/\|$//;
  $S32 =~ tr/[\(\)\*]+//;
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 Complex_Casting_Eval																			 ||
#		Description: This function is used for working around complex non constant Casted overflows					 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub Complex_Casting_Eval
{
  my @temp_OVFL_8;
  my @temp_OVFL_16;
  my @Unity_OF_8;
  my @Unity_OF_16;
  my (@temp_OVFL_1,@temp_OVFL_2);
  my @Duplicate_casting;
  my $i;
  my $j;
  my $brace_count;
  my $flag;
  #Collect all U8, S8, U16, S16 types parsed by function "Scan Types"
  my $pattern_typ_U8 = qr/$U8/;
  my $pattern_typ_U16 = qr/$U16/;
  my $pattern_typ_S8 = qr/$S8/;
  my $pattern_typ_S16 = qr/$S16/;
  # Capture All Duplicate casting in file "example : (UCHAR)(UCHAR)"
  @Duplicate_casting = $wholeFile =~ /\(\s*(\s*(?:$pattern_typ_U8|$pattern_typ_S8|$pattern_typ_U16|$pattern_typ_S16)\s*\)\s*\(\s*(?:$pattern_typ_U8|$pattern_typ_S8|$pattern_typ_U16|$pattern_typ_S16)\s*\))/g;
  # Remove one of the duplicates
  foreach my $Dup (@Duplicate_casting)
  {
    my $temp_Dup = $Dup;
    $Dup =~ s/\(.[^\(\)]*\)//;
    $wholeFile =~ s/\Q$temp_Dup\E/$Dup/g;
  }
  #Capture all U8, S8 Casting in file
  @temp_OVFL_8 = $wholeFile =~ /(\(\s*(?:$pattern_typ_U8|$pattern_typ_S8)\s*\)\s*\(.[^,:\{\};]*;)/g;
  #Capture all U16, S16 Casting in file
  @temp_OVFL_16 = $wholeFile =~ /(\(\s*(?:$pattern_typ_U16|$pattern_typ_S16)\s*\)\s*\(.[^,:\{\};]*;)/g;
  my $Brace_Counter_Units;
  my $Type_Flag;
  my $Neg_Comp = 0;
  my $Neg_flag = 0;
  my $prev_unit;
  my $temp_unit;
  my $tempvar;
  my $LineEndUnbalanced = 0;
  my $bIssuccessiveCasting = 0;
  my @SuccessiveCastCount;
  $Recursion = 1;
  # Recursion Base Condition "Recursion is used because this function captures only 1 casting statment per line, thus we need another calls to capture the rest"
  if((scalar @temp_OVFL_8 + scalar @temp_OVFL_16) == 0 )
  {
    $Recursion = 0;
    $wholeFile =~ s/\/\*Done\*\///g;
    return;
  }
  # Capture the U8, S8 Casted statment from whole line "example : Captures ((UCHAR)(x+y)) from ((UCHAR)(x+y)-a+b;)"
  foreach my $unit8 (@temp_OVFL_8)
  {
      next if($prev_unit eq $unit8);
      $Brace_Counter_Units = 0;
      $Type_Flag = 0;
      if($unit8 =~ m/^\(\s*($pattern_typ_U8|$pattern_typ_S8)\s*\)\s*\(\/\*neg\*\//)
      {
        $Neg_Comp = 1;
      }
	  if ($unit8 =~ m/^\(\s*UInt8\s*\)\s*\(\s*Int16\s*\)/)
	  {
		$bIssuccessiveCasting = 1;
	  }
      for($i = 0;$i<length($unit8);$i++)
      {
          if(substr($unit8,$i,1) eq "(")
          {
              $Brace_Counter_Units++;
          }
          elsif(substr($unit8,$i,1) eq ")")
          {
              $Brace_Counter_Units--;
          }
          else
          {   if($i != (length($unit8)-1))
              {
                next if($Brace_Counter_Units == 0);
              }
              else
              {
                if($Brace_Counter_Units == 0)
                {
                  if($Neg_Comp)
                  {
                     $Neg_Comp = 0;
                  }
                  else
                  {
                    #Do Nothing
                  }
                }
                else
                {
                  $Neg_Comp = 0;
                  $LineEndUnbalanced = 1;
                }
              }
          }
          if($Brace_Counter_Units == 0 && !$Type_Flag)
          {
              $Type_Flag = 1;
          }
          elsif(($Brace_Counter_Units == 0 && $Type_Flag) || $LineEndUnbalanced)
          {
            if($Neg_Comp == 1)
            {
              #$Neg_Comp = 0;
              next;
            }
            if($LineEndUnbalanced)
            {
               $i--;
            }
            $temp_unit =  substr($unit8,0,$i+1);
			push(@temp_OVFL_1,$temp_unit);
            if (($unit8 =~ m/\Q$temp_unit\E\s*\./) || $bIssuccessiveCasting)
		   {
			  $temp_unit =~ s/^\(/(\/*Drop*\//;
		   }
		   push(@Unity_OF_8,$temp_unit);
            last;
          }
      }
      $prev_unit = $unit8;
      $LineEndUnbalanced = 0;
	  $bIssuccessiveCasting = 0;
   @SuccessiveCastCount = ();
  }
  $Neg_Comp = 0;
  $Neg_flag = 0;
  $prev_unit = "";
  $bIssuccessiveCasting = 0;
  # Capture the U16, S16 Casted statment from whole line "example : Captures ((USHORT)(x+y)) from ((USHORT)(x+y)-a+b;)"
  foreach my $unit16 (@temp_OVFL_16)
  {
      next if($prev_unit eq $unit16);
      $Brace_Counter_Units = 0;
      $Type_Flag = 0;
      if($unit16 =~ m/^\(\s*($pattern_typ_U16|$pattern_typ_S16)\s*\)\s*\(\/\*neg\*\//)
      {
        $Neg_Comp = 1;
      }
	  if ($unit16 =~ m/^\(\s*UInt16\s*\)\s*\(\s*Int8s*\)/)
	  {
		$bIssuccessiveCasting = 1;
	  }
      for($i = 0;$i<length($unit16);$i++)
      {
          if(substr($unit16,$i,1) eq "(")
          {
              $Brace_Counter_Units++;
          }
          elsif(substr($unit16,$i,1) eq ")")
          {
              $Brace_Counter_Units--;
          }
          else
          {
              if($i != (length($unit16)-1))
              {
                next if ($Brace_Counter_Units == 0);
              }
              else
              {
                if($Brace_Counter_Units == 0)
                {
                  if($Neg_Comp)
                  {
                     $Neg_Comp = 0;
                  }
                  else
                  {
                    #Do Nothing
                  }
                }
                else
                {
                   $Neg_Comp = 0;
                }
              }
          }
          if($Brace_Counter_Units == 0 && !$Type_Flag)
          {
              $Type_Flag = 1;
          }
          elsif(($Brace_Counter_Units == 0 && $Type_Flag) || $LineEndUnbalanced)
          {
            if($Neg_Comp == 1)
            {
              next;
            }
            if($LineEndUnbalanced)
            {
              $i--;
            }
            $temp_unit =  substr($unit16,0,$i+1);
            push(@temp_OVFL_2,$temp_unit);
            if (($unit16 =~ m/\Q$temp_unit\E\s*\./) || $bIssuccessiveCasting)
            {
				$temp_unit =~ s/^\(/(\/*Drop*\//;
            }
			push(@Unity_OF_16,$temp_unit);
            last;
          }
      }
      $prev_unit = $unit16;
      $LineEndUnbalanced = 0;
	  $bIssuccessiveCasting = 0;
  }
   my $Type_unit;
   # Apply workaround on statment
   for ($i = 0;$i<scalar @Unity_OF_8;$i++)
   {
      $Unity_OF_8[$i] =~ s/^[ \t]*//;
      $Unity_OF_8[$i] =~ s/[; \t]*$//;
      if ($Unity_OF_8[$i] =~ m/\/*Drop\*\//)
	     {
		      $Unity_OF_8[$i] =~ s/\/\*Drop\*\///;
		      next;
	     }
     ($Type_unit) = $Unity_OF_8[$i] =~ /(^\(\s*(?:$pattern_typ_U8|$pattern_typ_S8)\s*\))/;
     $Unity_OF_8[$i] =~ s/\(\s*($pattern_typ_U8|$pattern_typ_S8)\s*\)\s*\(/$Type_unit((0xFF) & (/;
     $Unity_OF_8[$i] = $Unity_OF_8[$i]. ")";#~ s/\)$/))/;
     $Unity_OF_8[$i] =~ s/\/\*neg\*\///;
   }
   for ($i = 0;$i<scalar @Unity_OF_16;$i++)
   {
      $Unity_OF_16[$i] =~ s/^[ \t]*//;
      $Unity_OF_16[$i] =~ s/[; \t]*$//;
      if ($Unity_OF_16[$i] =~ m/\/\*Drop\*\//)
	     {
		    $Unity_OF_16[$i] =~ s/\/\*Drop\*\///;
		    next;
	     }
     ($Type_unit) = $Unity_OF_16[$i] =~ /(^\(\s*(?:$pattern_typ_U16|$pattern_typ_S16)\s*\))/;
     $Unity_OF_16[$i] =~ s/\(\s*($pattern_typ_U16|$pattern_typ_S16)\s*\)\s*\(/$Type_unit((0xFFFF) & (/;
     $Unity_OF_16[$i] = $Unity_OF_16[$i]. ")";#~ s/\)$/))/;
     $Unity_OF_16[$i] =~ s/\/\*neg\*\///;
   }
   # Trimming
  for($i = 0 ; $i<scalar @temp_OVFL_1; $i++)
  {
     $temp_OVFL_1[$i] =~ s/;*$//g;
     $Unity_OF_8[$i] =~ s/;*$//g;
  }
  for($i = 0 ; $i<scalar @temp_OVFL_2; $i++)
  {
     $temp_OVFL_2[$i] =~ s/;*$//g;
     $Unity_OF_16[$i] =~ s/;*$//g;
   }
   # Mark the worked around ones so that in the next recursive call the are not captured and replace the casted statments in code with worked around ones
  for($i = 0 ; $i<scalar @temp_OVFL_1; $i++)
  {
    $tempvar = $temp_OVFL_1[$i];
    substr($Unity_OF_8[$i],1,0) = "/*Done*/";
    if($tempvar =~ m/^\(\s*($pattern_typ_U8|$pattern_typ_S8)\s*\)\s*\n/)
    {
       $Unity_OF_8[$i] = "\n".$Unity_OF_8[$i];
    }
    $wholeFile =~ s/\Q$tempvar\E/$Unity_OF_8[$i]/g;
  }
  for($i = 0 ; $i<scalar @temp_OVFL_2; $i++)
  {
    $tempvar = $temp_OVFL_2[$i];
    substr($Unity_OF_16[$i],1,0) = "/*Done*/";
    if($tempvar =~ m/^\(\s*($pattern_typ_U16|$pattern_typ_S16)\s*\)\s*\n/)
    {
       $Unity_OF_16[$i] = "\n".$Unity_OF_16[$i];
    }
    $wholeFile =~ s/\Q$tempvar\E/$Unity_OF_16[$i]/g;
  }
  #recursive call
  if($Recursion)
  {
    Complex_Casting_Eval();
  }
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 ToString																			 		 	 ||
#		Description: This function is used for Printing the code lines after processing to STDOUT "Standard output"  ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub ToString
{	
  unlink("out.txt");
	@lines = split("\n", $wholeFile);
	open (FILEOUT, '>>out.txt')
	or die "Cannot open red_errors file";
  #foreach my $line (@lines)
  #{
    print FILEOUT $wholeFile;
  #}
  print "Finished";
  close (FILEOUT);
}

#--------------------------------------------------------------------------------------------------------------------||
#		Function: 	 main																			 		 	 	 ||
#		Description: Main Function  																				 ||
#		Arguments:	 None.																							 ||
#--------------------------------------------------------------------------------------------------------------------||

sub main()
{
	# Load XML file Containning Snippits to be repalced
	$XmlData = $Snippits->XMLin("Red_Errors.xml", KeyAttr => {Snippit => 'SnippitID'});
	# First Load all lines to 1 big string.
	ConcatenateFileLines();
	# Replace the User defined Code using Snippits loaded from XML
	RemoveRedErrors(0);
	# Remove unwanted Keywords
	RemoveKeywords();
	# Split back the lines in global array.
	@lines = split("\n", $wholeFile);
	#Scan All Data Types in File
	Scan_Data_Types();
	#Workaround all negations in File
	Replace_neg_general();
	# remove Asm functions
	RemoveAssemblyFunctions();
	# remove Asm blocks
	Replace_Asm_Block();
	# Replace #pragma asm Blocks.
	Remove_Pragma_Asm();
	# Replace asm("") cases	
	Remove_asm_func_call();
	# Replace Remainning # pragma directives
	Remove_pragma_Asm_line();
	#Concatinate back all Lines again in 1 String to be processed by Complex workaround functions
	$wholeFile = join("\n", @lines);
	#Workaround all the unsigned Constant Overflows in File
	Replace_Casting_overflows_unsigned();
	#Workaround all the signed Overflows in file
	Replace_Casting_overflows_signed();
	#This function workaround non constant overflows in file
	Complex_Casting_Eval();
	#Make another loop on snippits to replaced the snippits not replaced in first loop
	RemoveRedErrors(1);
	# output the processed lines.
	ToString();
}

#Calling main
main();
