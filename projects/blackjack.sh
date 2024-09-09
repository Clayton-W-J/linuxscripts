#!/bin/bash

# Array that specifies all 52 cards in a deck
cards_in_a_deck=("Ace of Spades" "2 of Spades" "3 of Spades" "4 of Spades" "5 of Spades" "6 of Spades" "7 of Spades" "8 of Spades" "9 of Spades" "10 of Spades" "Jack of Spades" "King of Spades" "Queen of Spades" "Ace of Diamonds" >

# Randomly call objects from the deck array
random_element=${cards_in_a_deck[ $RANDOM % ${#cards_in_a_deck[@]} ]}

clear
echo "Welcome to CJ's Blackjack! Do you wish to play? y/n"
read -s -n 1 game_acceptance

# If statement to accecpt or decline playing the game
clear
if [ $game_acceptance = 'y' ]; then
    printf "How much money would you like to start with? "
else
    echo "Quitting application"
fi

# Setting the user bet then dealing first card
read users_bet
clear
echo "You're bet is \$${users_bet}, is this correct? y/n"
read -s -n 1 bet_check
clear
if [ $bet_check = 'y' ]; then
    printf "The bet is correct!\n"
else
   printf "The bet is incorrect!\n"
fi
