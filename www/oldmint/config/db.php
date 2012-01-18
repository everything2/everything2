<?php
/******************************************************************************
 Mint
  
 Copyright 2004-2007 Shaun Inman. This code cannot be redistributed without
 permission from http://www.shauninman.com/
 
 More info at: http://www.haveamint.com/
 
 ******************************************************************************
 Configuration
 ******************************************************************************/
 if (!defined('MINT')) { header('Location:/'); }; // Prevent viewing this file 

$Mint = new Mint (array
(
	'server'	=> 'db2',
	'username'	=> 'e2mint',
	'password'	=> 'hJfIrvX6dF4Q',
	'database'	=> 'e2mint',
	'tblPrefix'	=> 'e2mint_'
));
