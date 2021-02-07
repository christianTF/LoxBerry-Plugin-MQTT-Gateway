#!/usr/bin/php
<?php
	if( $argv[1] == 'skills' ) {
		echo "description=Example of incoming json and outgoing json data\n";
		echo "input=json\n";
		echo "output=json\n";
		exit();
	}
	
	// Remove the script name from parameters
	array_shift($argv);
	// Join together all command line arguments
	$commandline = implode( ' ', $argv );	
	// Parse json into an array
	$dataset = json_decode( $commandline, 1 );
	// Get the first element of the array
	$topic = array_key_first($dataset);
	$data = $dataset[$topic];
		
	// Modify the data
	
	// We don't need to change the topic, but we can!
	// And we can multiple data out of one dataset
	$timetopic = $topic.'/'.'time';
	$datetopic = $topic.'/'.'date';
	
	// We modify the data (we add the time)
	$data = $data . ' ('.date('H:i:s').')';
	
	// Now print multiple data to stdout
	$dataarray = array();
	array_push( $dataarray, array ( $topic => $data ) );
	array_push( $dataarray, array ( $timetopic => date('H:i:s') ) );
	array_push( $dataarray, array ( $datetopic => date('m.d.y') ) );
	
	// $dataarray = array (
		// 0 => array ( $topic => $data ),
		// 1 => array ( $timetopic => date('H:i:s') ),
		// 2 => array ( $datetopic => date('m.d.y') )
	// );
	
	// Output data as json
	echo json_encode( $dataarray );
	
	// Thank you and good bye
	exit;
