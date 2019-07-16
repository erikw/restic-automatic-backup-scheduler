#!/bin/bash

metered_status=$(dbus-send --system --print-reply=literal \
       	--system --dest=org.freedesktop.NetworkManager \
	      /org/freedesktop/NetworkManager \
	      org.freedesktop.DBus.Properties.Get \
	      string:org.freedesktop.NetworkManager string:Metered \
	      | grep -o ".$")

if [[ $metered_status =~ (1|3) ]]; then
  echo Current connection is metered
  exit 1
else 
  exit 0
fi

