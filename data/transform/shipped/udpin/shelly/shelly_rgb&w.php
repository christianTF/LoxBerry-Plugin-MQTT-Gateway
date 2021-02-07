#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Shelly RGB and WHITE control for RGB/W devices\n";
		echo "link=https://www.loxwiki.eu/x/_QBABQ\n";
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
	
	list($command, $value_pct) = explode( ' ', $data);
	
	$data = array (	
		'effect' => 0,
		'gain' => 100,
		'turn' => 'on',
		'mode' => 'color'
	);
	
	switch ($command) {
		// Color mode
		case 'white': 
			$white = round( $value_pct / 100 * 255 );
			$data['white'] = $white;
			break;
		case 'rgb':
			$rgb_pct = str_pad( $value_pct, 9, '0', STR_PAD_LEFT );
			$red = round( substr( $rgb_pct, -3, 3) / 100 * 255 );
			$green = round( substr( $rgb_pct, -6, 3) / 100 * 255 );
			$blue = round( substr( $rgb_pct, -9, 3) / 100 * 255 );
			$data['red'] = $red;
			$data['green'] = $green;
			$data['blue'] = $blue;
			break;
		default:
			error_log('Transformer shelly_rgb&w: Wrong parameters (white or rgb missing)');
	}
	
	echo $topic."#".json_encode($data)."\n";
	