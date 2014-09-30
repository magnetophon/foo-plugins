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
import ("rms.dsp");

import ("biquad-hpf.dsp");
import ("rms.dsp");



// 
MAX_flt = fconstant(int LDBL_MAX, <float.h>);
MIN_flt = fconstant(int LDBL_MIN, <float.h>);

main_group(x)  = (hgroup("[1]", x));

meter_group(x)  = main_group(hgroup("[1]", x));
knob_group(x)   = main_group(hgroup("[2]", x));

compressor_group(x)  = knob_group(vgroup("[1]", x));
post_group(x)        = knob_group(vgroup("[2]", x));

drywet		 = compressor_group(hslider("[0]dry-wet[tooltip: ]", 1.0, 0.0, 1.0, 0.1));
ingain      = compressor_group(hslider("[1] Input Gain [unit:dB]   [tooltip: The input signal level is increased by this amount (in dB) to make up for the level lost due to compression]",0, -40, 40, 0.1) : db2linear : smooth(0.999));
peakRMS     = compressor_group(hslider("[2] peak/RMS [tooltip: Peak or RMS level detection",1, 0, 1, 0.001));
rms_speed   = compressor_group(hslider("[3]RMS speed[tooltip: ]",96, 1,   440,   1)*44100/SR); //0.0005 * min(192000.0, max(22050.0, SR));
threshold   = compressor_group(hslider("[4] Threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -21.1, -80, 0, 0.1));
ratio       = compressor_group(hslider("[5] Ratio   [tooltip: A compression Ratio of N means that for each N dB increase in input signal level above Threshold, the output level goes up 1 dB]", 20, 1, 20, 0.1));
attack      = compressor_group(time_ratio_attack(hslider("[6] Attack [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new lower target level (the compression `kicking in')]", 70.8, 0.1, 500, 0.1)/1000)) ;
release     = compressor_group(time_ratio_release(hslider("[7] Release [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",83.5, 0.1, 2000, 0.1)/1000));
//hpf_switch  = compressor_group(select2( hslider("[8]sidechain hpf[tooltip: ]", 1, 0, 1, 1), 1.0, 0.0));
hpf_freq    = compressor_group( hslider("[8]sidechain hpf[tooltip: ]", 101, 1, 400, 1));


prePower      = post_group(hslider("[0]pre power[tooltip: ]", 8.4, 1,33 , 0.001):pow(3));
ratelimit     = post_group(hslider("[1]ratelimit[tooltip: ]", 1, 0, 1 , 0.001));
maximum_rate  = post_group(hslider("[2]maximum rate[tooltip: ]", 7.272, 1, 50 , 0.001):pow(4)/SR);
postPower     = post_group(hslider("[3]post power[tooltip: ]", 3.048, 1, 33 , 0.001):pow(3));
maxGR         = post_group(hslider("[4] Max Gain Reduction [unit:dB]   [tooltip: The maximum gain reduction]",-12, -60, 0, 0.1) : db2linear : smooth(0.999));
curve         = post_group(hslider("[5]curve[tooltip: ]", -0.797, -1, 1 , 0.001));
feedFwBw      = post_group(hslider("[6]feedback/feedforward[tooltip: ]", 0.000, 0, 1 , 0.001));
outgain       = post_group(hslider("[7]output gain (dB)[tooltip: ]",           0,      -40,   40,   0.1):smooth(0.999)); // DB
shape         = post_group(hslider("[8]shape[tooltip: ]", 10, 1, 10 , 0.001):pow(2));

/*threshold	 = hslider("threshold (dB)",         -10.0,  -60.0,   10.0, 1.0);*/
/*attack		 = time_ratio_attack( hslider("attack (ms)", 10.0,    0.001,  400.0, 0.001) / 1000 );*/
/*release		 = time_ratio_release( hslider("release (ms)", 300,   0.1, 1200.0, 0.001) / 1000 );*/

/*ratio		 = hslider("compression ratio",          5,    1.5,   20,   0.5);*/


bypass_switch = select2( hslider("bypass[tooltip: ]", 0, 0, 1, 1), 1.0, 0.0);

envelop = abs : max ~ -(1.0/SR) : max(db2linear(-70)) : linear2db;
meter = meter_group(_<:(_, (envelop :(vbargraph("[1][unit:dB][tooltip: input level in dB]", -60, +0)))):attach);


powlim(x,base) = x:max(log(MAX_flt)/log(base)):  min(log(MIN_flt)/log(base));

SATURATE(x) = tanh(x);
//SATURATE(x) = 2 * x * (1-abs(x) * 0.5);

MAKEITFAT(gain,dry) = (dry * (gain:meter));// + (SATURATE(dry / db2linear(threshold)) * db2linear(threshold) * (1 - gain));

crossfade(x,a,b) = a*(1-x),b*x : +;

/*COMP = (_ <: ( HPF : DETECTOR : RATIO : db2linear )):pow(power);*/


rmsFade = _<:crossfade(peakRMS,_,RMS(rms_speed)); // bypass makes the dsp double as efficient. On silence RMS takes double that (so in my case 7, 13 and 21 %)

/*COMP = (1/((1/(((_ <: ( HPF : DETECTOR : RATIO : db2linear : max(db2linear(-140)) : min (1) :pow(prePower):linear2db*/
/*<: ( RATELIMITER ~ _ ),_:crossfade(ratelimit) : db2linear ): max(MIN_flt) : min (MAX_flt)):pow(1/postPower))):max(db2linear(-140))*maxGR*2*PI:tanh:/(2*PI))/maxGR)):min(1);*/

detector = ((_ <: ( HPF(hpf_freq) :rmsFade: DETECTOR : RATIO : db2linear:min(1):max(MIN_flt)<:_,_:pow(powlim( prePower)):linear2db
<: _,( RATELIMITER ~ _ ):crossfade(ratelimit) : db2linear :min(1):max(MIN_flt)))<:_,_:pow(powlim(1/postPower)));


maxGRshaper = _;//max(maxGR);
//maxGRshaper = (1/((1/_*maxGR*2*PI:tanh:/(2*PI))/maxGR)):min(1);

tanshape(amp,x) =(tanh(amp*(x-1)))+1;

//((tanh(amp*((x*2)-1)))/2)+0.5;


curve_pow(fact,x) = ((x*(x>0):pow(p))+(x*-1*(x<=0):pow(p)*-1)) with
{
    p = exp(fact*10*(log(2)));
};



COMP = detector:maxGRshaper:(_-maxGR)*(1/(1-maxGR)): curve_pow(curve):tanshape(shape):_*(1-maxGR):_+maxGR;

blushcomp =_*ingain: (_ <:( crossfade(feedFwBw,_,_),_ : ( COMP , _ ) : MAKEITFAT)~_)*(db2linear(outgain));

process =blushcomp, blushcomp;

/*process = tanshape;*/


