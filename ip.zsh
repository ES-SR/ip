#! /usr/bin/env zsh

# aliases and functions for ip management
function CustomPing {
  # if no arguments are passed, ping 1.1.1.1 5 times with domain name resolution
  local evalString=""
  if [[ ${#@} -eq 0 ]]; then
    evalString="/usr/bin/ping -c 5 -H 1.1.1.1"
  elif [[ ${#@} -eq 1 ]]; then
    evalString="/usr/bin/ping -c 5 -H $1"
  else
    evalString="/usr/bin/ping $@"
  fi

  # eval the string and colorize the output
  local SO=$(tput smso)
  local GREEN=$(tput setaf 2)
  local RED=$(tput setaf 1)
  local YELLOW=$(tput setaf 3)
  local CYAN=$(tput setaf 6)
  local BLUE=$(tput setaf 4)
  local RESET=$(tput sgr0)
  eval $evalString        \
  | awk                   \
      -v SO=$SO           \
      -v GREEN=$GREEN     \
      -v RED=$RED         \
      -v YELLOW=$YELLOW   \
      -v CYAN=$CYAN       \
      -v BLUE=$BLUE       \
      -v RESET=$RESET     \
    '
    BEGIN {
      printStr = ""
    }
    {
      for(i=1; i<=NF; i++) {
        # match ip addresses
        if( $i ~ /[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+/ ) {
          printStr = printStr CYAN $i RESET " "
        # match ping time and color part after =
        } else if( $i ~ /time=/ ) {
          split($i, time, "=")
          printStr = printStr time[1] "=" GREEN time[2] RESET " "
        # match packet loss and color based on percentage
        } else if( $i ~ /%/ ) {
          if( $i ~ /0%/ ) {
            printStr = printStr GREEN $i RESET " "
          } else if( $i ~ /100%/ ){
            printStr = printStr RED $i RESET " "
          } else {
            printStr = printStr YELLOW $i RESET " "
          }
        # match min/avg/max/mdev values
        } else if( $i ~ /[0-9]+[.][0-9]+\// ) {
          printStr = printStr BLUE $i RESET " " 
        } else {
          printStr = printStr $i " "
        }
      }
      print printStr
      printStr = ""
    }
    '
}
compdef CustomPing=ping # Zsh Command Completion for CustomPing
alias ping=CustomPing # override the default ping command

alias wg='sudo wg'

function ShowDns {
  sudo cat /etc/resolv.conf  \
  | awk '# color "nameserver" orange and ip address green if pingable, red if not
    BEGIN {
      printStr = ""
    }
    /^nameserver/ {
      for(i=1; i<=NF; i++) {
        # match nameserver
        if( $i ~ /nameserver/ ) {
          printStr = printStr "\033[0;34m" $i "\033[0m" " "
        # match ip addresses
        } else if( $i ~ /[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+/ ) {
          # ping the ip address
          if( system("ping -c 1 -W 1 " $i " > /dev/null") == 0 ) {
            printStr = printStr "\033[0;32m" $i "\033[0m" " "
          } else {
            printStr = printStr "\033[0;31m" $i "\033[0m" " "
          }
        } else {
          printStr = printStr $i " "
        }
      }
      print printStr
      printStr = ""
    }
  '
}
alias showDns=ShowDns

function CustomIp {
# convenient tweaks to the ip command including default use of sudo, -human and
# -color options, and address subcommand, as well as adding basic temporary dns
# management through /etc/resolv.conf
  if [ -z "$1" ]; then
    sudo /usr/sbin/ip -human -color a
  else
    case $1 in
      dns)
        # add dns set|delete|show (temporary) functionality to ip command 
        # by modifying /etc/resolv.conf
        case $2 in
          add)
            # save backup of resolv.conf then append 'nameserver $3' to resolv.conf
            sudo cp -b /etc/resolv.conf /etc/resolv.conf~
            # if $3 is not an ip address, resolve it to an ip address
            local Server=$3
            if [[ ! $Server =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
              Server=$(dig +short $Server)
            fi
            echo "nameserver $Server"  \
            | sudo tee -a /etc/resolv.conf  \
            > /dev/null
            showDns
            ;;
          set)
            # save backup of resolv.conf then write 'nameserver $3' to resolv.conf
            sudo cp -b /etc/resolv.conf /etc/resolv.conf~
            # if $3 is not an ip address, resolve it to an ip address
            local Server=$3
            if [[ ! $Server =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
              Server=$(dig +short $Server)
            fi
            echo "nameserver $Server" | sudo tee /etc/resolv.conf
            showDns
            ;;
          delete)
            # save backup of resolv.conf then remove 'nameserver $3' from resolv.conf
            sudo cp -b /etc/resolv.conf /etc/resolv.conf~
            sudo sed -i "/nameserver $3/d" /etc/resolv.conf
            showDns
            ;;
          help)
            echo "Usage: ip dns set [nameserver ip]"
            echo ""
            echo "       ip dns delete [nameserver ip]"
            echo ""
            echo "       ip dns show [nameserver ip]"
            ;;
          *|show)
            showDns
            ;;
        esac
        ;;
      ping)
        if [ $2 = "help" ]; then
          echo "Usage: ip ping [options] [destination]"
          echo ""
          echo "       ip ping [destination]"
          echo ""
          echo "       ip ping -c [count] [destination]"
          echo ""
          echo "       ip ping -H [destination]"
          echo ""
          echo "       ip ping -h"
        else
          shift # remove 'ping' from arguments before passing to CustomPing
          CustomPing $@
        fi
        ;;
      *)
        sudo /usr/sbin/ip -human -color $@
        ;;
    esac
  fi
}
# Zsh Command Completion for CustomIp
compdef CustomIp=ip
alias ip=CustomIp


