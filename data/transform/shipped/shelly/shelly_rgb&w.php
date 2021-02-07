#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Example of incoming text and outgoing text\n";
		echo "input=text\n";
		echo "output=text\n";
		exit();
	}
	
	// ---- THIS CAN BE USED ALWAYS ----
	// Remove the script name from parameters
	array_shift($argv);
	// Join together all command line arguments
	$commandline = implode( ' ', $argv );	
	// Split topic and data by separator
	list( $topic, $data ) = explode( '#', $commandline, 2);
	// ----------------------------------
	
	list($white_pct, $rgb_pct) = explode( ' ', $data);
	
	$white = round( $white_pct / 100 * 255 );
	
	$rgb_pct = str_pad( $rgb_pct, 9, '0', STR_PAD_LEFT );
	$red = round( substr( $rgb_pct, -3, 3) / 100 * 255 );
	$green = round( substr( $rgb_pct, -6, 3) / 100 * 255 );
	$blue = round( substr( $rgb_pct, -9, 3) / 100 * 255 );
	
	if( ($white+$red+$green+$blue) == 0 ) {
		$turn = 'off';
	} else {
		$turn = 'on';
	}
	
	$data = array (
		'mode' => 'color',
		'effect' => 0,
		'gain' => 100,
		'turn' => $turn,
		'white' => $white,
		'red' => $red,
		'green' => $green,
		'blue' => $blue
	);
	
	// Now print multiple data to stdout
	echo $topic."#".json_encode($data)."\n";
	