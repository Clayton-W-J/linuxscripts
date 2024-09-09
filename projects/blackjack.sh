#!/bin/bash

# Array that specifies all 52 cards in a deck
cards_in_a_deck=("Ace of Spades" "2 of Spades" "3 of Spades" "4 of Spades" "5 of>

# Randomly call objects from the deck array
random_element=${cards_in_a_deck[ $RANDOM % ${#cards_in_a_deck[@]} ]}

clear
echo "Welcome to CJ's Blackjack! Do you wish to play? y/n"
read -s -n 1 game_acceptance

clear
# If statement to accept or decline playing the game
if [ "$game_acceptance" = 'y' ]; then
    while true; do
        # Ask the user how much money they would like to start with
        printf "How much money would you like to start with? "

        # Read the user's bet
        read users_bet
        clear

        # Ask if the bet is correct
        echo "Your bet is \$${users_bet}, is this correct? y/n"
        read -s -n 1 bet_check
        clear

        # Check if the bet is correct
        if [ "$bet_check" = 'y' ]; then
            break
        fi
    done
fi

# Options menu
printf "1. Dealer's Hand\n2. Your hand\n3. Money\n\nWhich would you like to choo>
read user_menu_option
if [ $user_menu option = '3' ]; then
    printf "$users_bet"
