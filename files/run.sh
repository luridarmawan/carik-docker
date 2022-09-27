#!/bin/bash
echo
echo Running Apache Web Server for Carik Chatbot..
echo
echo try from your browser
echo http://localhost:8080
echo
echo ECHO Example
echo http://localhost:8080/echo/?val1=value1
echo
echo Chatbot BaseURL
echo http://localhost:8080/carik/
echo
echo press Ctrl+C to exit
/usr/sbin/apache2ctl -D FOREGROUND
