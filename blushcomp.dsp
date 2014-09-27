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

import ("compressor-basics.dsp");

import ("biquad-hpf.dsp");

feedbackSW = hslider("[1]feedback/feedforward", 0, 0, 1 , 1);
envelop = abs : max ~ -(1.0/SR) : max(db2linear(-70)) : linear2db;
meter = (_<:(_, (envelop :(vbargraph("[3][unit:dB][tooltip: input level in dB]", -30, +0)))):attach);
power = hslider("power", 1, 1, 11 , 0.001)*3:pow(3);
ratelimit = hslider("ratelimit", 0, 0, 1 , 1);

SATURATE(x) = tanh(x);
//SATURATE(x) = 2 * x * (1-abs(x) * 0.5);

MAKEITFAT(gain,dry) = (dry * (gain:meter));// + (SATURATE(dry / DB2COEFF(threshold)) * DB2COEFF(threshold) * (1 - gain));


/*COMP = (_ <: ( HPF : DETECTOR : RATIO : DB2COEFF )):pow(power);*/
COMP = (_ <: ( HPF : DETECTOR : RATIO <: ( RATELIMITER ~ _ ),_:select2(ratelimit) : DB2COEFF )):pow(power);
blushcomp =(_ <:( select2(feedbackSW,_,_),_ : ( COMP , _ ) : MAKEITFAT)~_)*(db2linear(makeup_gain));
process = blushcomp, blushcomp;


