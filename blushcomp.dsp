//todo: limiter/clipper in the fb path
/*
 *  Copyright (C) 2009 Sampo Savolainen
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 */

/*

 contort'o'comp
 warp
 garble
 

 impact

*/

declare name      "foo blushcomp mono";
declare author    "Sampo Savolainen";
declare version   "0.9b";
declare copyright "(c)Sampo Savolainen 2009";

import ("math.lib");
import ("music.lib");
import ("filter.lib");

import ("compressor-basics.dsp");

import ("biquad-hpf.dsp");

ratio     = hslider("[1] Ratio   [tooltip: A compression Ratio of N means that for each N dB increase in input signal level above Threshold, the output level goes up 1 dB]", 20, 1, 20, 0.1);
threshold = hslider("[2] Threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -20, -20, 20, 0.1);
attack    = time_ratio_attack(hslider("[3] Attack [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new lower target level (the compression `kicking in')]", 36.7, 0.1, 500, 0.1)/1000) ;
release   = time_ratio_release(hslider("[4] Release [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",81.4, 0.1, 2000, 0.1)/1000);
ingain    = hslider("[5] Input Gain [unit:dB]   [tooltip: The input signal level is increased by this amount (in dB) to make up for the level lost due to compression]",10.1, -40, 40, 0.1) : db2linear : smooth(0.999);
maxGR     = hslider("[6] Max Gain Reduction [unit:dB]   [tooltip: The maximum gain reduction]",-28.5, -140, 0, 0.1) : db2linear : smooth(0.999);

rms_speed        = 0.0005 * min(192000.0, max(22050.0, SR));

/*threshold	 = hslider("threshold (dB)",         -10.0,  -60.0,   10.0, 1.0);*/
/*attack		 = time_ratio_attack( hslider("attack (ms)", 10.0,    0.001,  400.0, 0.001) / 1000 );*/
/*release		 = time_ratio_release( hslider("release (ms)", 300,   0.1, 1200.0, 0.001) / 1000 );*/

/*ratio		 = hslider("compression ratio",          5,    1.5,   20,   0.5);*/
makeup_gain 	 = hslider("[6]makeup gain (dB)",           -6,      -40,   40,   0.5); // DB

drywet		 = hslider("dry-wet", 1.0, 0.0, 1.0, 0.1);

bypass_switch = select2( hslider("bypass", 0, 0, 1, 1), 1.0, 0.0);

feedFwBw = hslider("[1]feedback/feedforward", 0.008, 0, 1 , 0.001);
envelop = abs : max ~ -(1.0/SR) : max(db2linear(-70)) : linear2db;
meter = (_<:(_, (envelop :(vbargraph("[3][unit:dB][tooltip: input level in dB]", -30, +0)))):attach);
prePower = hslider("pre power", 7.504, 1, 11 , 0.001)*3:pow(3);
postPower = hslider("post power", 2.220, 1, 11 , 0.001)*3:pow(3);
ratelimit = hslider("ratelimit", 0, 0, 1 , 0.001);
maximum_rate = hslider("maximum rate", 9.366, 1, 50 , 0.001):pow(4)/SR;
hpf_switch = select2( hslider("sidechain hpf", 1, 0, 1, 1), 1.0, 0.0);

SATURATE(x) = tanh(x);
//SATURATE(x) = 2 * x * (1-abs(x) * 0.5);

MAKEITFAT(gain,dry) = (dry * (gain:meter));// + (SATURATE(dry / db2linear(threshold)) * db2linear(threshold) * (1 - gain));

crossfade(x,a,b) = a*(1-x),b*x : +;

/*COMP = (_ <: ( HPF : DETECTOR : RATIO : db2linear )):pow(power);*/
COMP = (1/((1/(((_ <: ( HPF : DETECTOR : RATIO : db2linear : max(maxGR) : min (1) :pow(prePower):linear2db<: ( RATELIMITER ~ _ ),_:crossfade(ratelimit) : db2linear )):pow(1/postPower))):max(maxGR)*maxGR*2*PI:tanh:/(2*PI))/maxGR)):min(1);
blushcomp =_*ingain: (_ <:( crossfade(feedFwBw,_,_),_ : ( COMP , _ ) : MAKEITFAT)~_)*(db2linear(makeup_gain));
process =blushcomp, blushcomp;
//process = crossfade(ratelimit);


