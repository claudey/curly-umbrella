#!/bin/bash

INPUT_FILE="domains.txt"

while read -r domain; do
  result=$(whois "$domain.com")
  if echo "$result" | grep -q "No match for"; then
    echo "$domain.com is AVAILABLE"
  else
    echo "$domain.com is TAKEN"
  fi
done < "$INPUT_FILE"
