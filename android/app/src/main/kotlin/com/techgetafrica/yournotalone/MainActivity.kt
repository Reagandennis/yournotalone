package com.techgetafrica.yournotalone

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity so a sound keeps playing with the screen
// locked, and the lock-screen controls work. Keeping our own class (rather
// than naming the plugin's activity directly in the manifest) leaves room
// for platform channels later.
class MainActivity : AudioServiceActivity()
