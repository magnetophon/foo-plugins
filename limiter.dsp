/*
 *  Copyright (C) 2014 Bart Brouns
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; version 2 of the License.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 */

/*


Based on blushcomp mono by Sampo Savolainen



 contort'o'comp
 warp
 garble
 

 impact

*/

declare name      "CleanComp";
declare author    "Bart Brouns";
declare version   "0.2";
declare copyright "(C) 2014 Bart Brouns";

import ("math.lib");
import ("music.lib");
import ("filter.lib");

import ("compressor-basics.dsp");
import ("rms.dsp");

import ("biquad-hpf.dsp");
import ("rms.dsp");

//the maximum size of the array for calculating the rms mean
//should be proportional to SR
// the size of a par() needs to be known at compile time, so (SR/100) doesn't work
rmsMaxSize = 512; //441

// 
MAX_flt = fconstant(int LDBL_MAX, <float.h>);
MIN_flt = fconstant(int LDBL_MIN, <float.h>);



main_group(x)  = (hgroup("[1]", x));

meter_group(x)  = main_group(hgroup("[1]", x));
knob_group(x)   = main_group(hgroup("[2]", x));

detector_group(x)  = knob_group(vgroup("[0]detector", x));
post_group(x)      = knob_group(vgroup("[1]", x));
ratelimit_group(x) = knob_group(vgroup("[2]ratelimit", x));

shape_group(x)      = post_group(vgroup("[0]shape", x));
out_group(x)        = post_group(vgroup("[2]", x));

envelop = abs : max ~ -(1.0/SR) : max(db2linear(-70)) : linear2db;
meter = meter_group(_<:(_, (linear2db :(vbargraph("[1][unit:dB][tooltip: input level in dB]", -60, 0)))):attach);

drywet        = detector_group(hslider("[0]dry-wet[tooltip: ]", 1.0, 0.0, 1.0, 0.1));
ingain        = detector_group(hslider("[1] Input Gain [unit:dB]   [tooltip: The input signal level is increased by this amount (in dB) to make up for the level lost due to compression]",0, -40, 40, 0.1) : db2linear : smooth(0.999));
peakRMS       = detector_group(hslider("[2] peak/RMS [tooltip: Peak or RMS level detection",1, 0, 1, 0.001));
rms_speed     = detector_group(hslider("[3]RMS size[tooltip: ]",96, 1,   rmsMaxSize,   1)*44100/SR); //0.0005 * min(192000.0, max(22050.0, SR));
threshold     = detector_group(hslider("[4] Threshold [unit:dB]   [tooltip: When the signal level exceeds the Threshold (in dB), its level is compressed according to the Ratio]", -27.1, -80, 0, 0.1));
ratio         = detector_group(hslider("[5] Ratio   [tooltip: A compression Ratio of N means that for each N dB increase in input signal level above Threshold, the output level goes up 1 dB]", 20, 1, 20, 0.1));
attack        = detector_group(time_ratio_attack(hslider("[6] Attack [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new lower target level (the compression `kicking in')]", 23.7, 0.1, 500, 0.1)/1000)) ;
release       = detector_group(time_ratio_release(hslider("[7] Release [unit:ms]   [tooltip: Time constant in ms (1/e smoothing time) for the compression gain to approach (exponentially) a new higher target level (the compression 'releasing')]",0.1, 0.1, 2000, 0.1)/1000));
//hpf_switch  = detector_group(select2( hslider("[8]sidechain hpf[tooltip: ]", 1, 0, 1, 1), 1.0, 0.0));
hpf_freq      = detector_group( hslider("[8]sidechain hpf[tooltip: ]", 154, 1, 400, 1));

powerScale(x) =((x>=0)*(1/((x+1):pow(3))))+((x<0)* (((x*-1)+1):pow(3)));
limPowerScale(x) =((x>=0)*(1/(x+1)))+((x<0)* ((x*-1)+1));

power          = shape_group(hslider("[1]power[tooltip: ]", 1.881 , -33, 33 , 0.001):powerScale);
limPower       = shape_group(hslider("[1]power[tooltip: ]", 1 , 0.5, 16 , 0.001));
IMpower        = shape_group(hslider("[1]IMpower[tooltip: ]", 1 , -16, 16 , 0.001)):limPowerScale;
maxGR          = shape_group(hslider("[2] Max Gain Reduction [unit:dB]   [tooltip: The maximum amount of gain reduction]",-15, -60, 0, 0.1) : db2linear : smooth(0.999));
curve          = shape_group(hslider("[3]curve[tooltip: ]", 0, -1, 1 , 0.001)*-1);
shape          = shape_group(((hslider("[4]shape[tooltip: ]", 94, 1, 100 , 0.001)*-1)+101):pow(2));


feedFwBw     = out_group(hslider("[0]feedback/feedforward[tooltip: ]", 0, 0, 1 , 0.001));
hiShelfFreq  = out_group(hslider("[1]hi shelf freq[tooltip: ]",134, 1,   400,   1));
gainHS       = out_group(hslider("[2]gain/hi-shelve crossfade[tooltip: ]", 0.811, 0, 1 , 0.001));
outgain      = out_group(hslider("[3]output gain (dB)[tooltip: ]",           0,      -40,   40,   0.1):smooth(0.999)); // DB

bypass_switch = select2( hslider("bypass[tooltip: ]", 0, 0, 1, 1), 1.0, 0.0);


ratelimit      = ratelimit_group(hslider("[0]ratelimit amount[tooltip: ]", 1, 0, 1 , 0.001));
maxRateAttack  = ratelimit_group(hslider("[1]max attack[unit:dB/s][tooltip: ]", 1020, 6, 8000 , 1)/SR);
maxRateDecay   = ratelimit_group(hslider("[2]max decay[unit:dB/s][tooltip: ]", 3813, 6, 8000 , 1)/SR);
decayMult      = ratelimit_group(hslider("[3]decayMult[tooltip: ]", 20000 , 0,1000000, 1));
decayPower     = ratelimit_group(hslider("[4]decayPower[tooltip: ]", 50, 0, 50 , 0.001));
IM_size        = ratelimit_group(hslider("[5]IM_size[tooltip: ]",108, 1,   rmsMaxSize,   1)*44100/SR); //0.0005 * min(192000.0, max(22050.0, SR));

powlim(x,base) = x:max(log(MAX_flt)/log(base)):  min(log(MIN_flt)/log(base));

gainPlusMeter(gain,dry) = (dry * (gain:meter));

hiShelfPlusMeter(gain,dry) = (dry :high_shelf(gain:meter:linear2db,hiShelfFreq));

gainHiShelfCrossfade(crossfade,gain,dry) = (dry * ((gain:meter:linear2db)*(1-crossfade):db2linear)): high_shelf(((gain:linear2db)*crossfade),hiShelfFreq);

gainLowShelfCrossfade(crossfade,gain,dry) = 
//dry*(gain:db2linear);
(dry * ((gain:dbmeter)*(1-crossfade):db2linear)): low_shelf(((gain)*crossfade),hiShelfFreq);


crossfade(x,a,b) = a*(1-x),b*x : +;


rmsFade = _<:crossfade(peakRMS,(_),RMS(rms_speed)); // bypass makes the dsp double as efficient. On silence RMS takes double that (so in my case 7, 13 and 21 %)

/*COMP = (1/((1/(((_ <: ( HPF : DETECTOR : RATIO : db2linear : max(db2linear(-140)) : min (1) :pow(prePower):linear2db*/
/*<: ( RATELIMITER ~ _ ),_:crossfade(ratelimit) : db2linear ): max(MIN_flt) : min (MAX_flt)):pow(1/power))):max(db2linear(-140))*maxGR*2*PI:tanh:/(2*PI))/maxGR)):min(1);*/

detector = ((_ <: ( HPF(hpf_freq) :rmsFade: DETECTOR : RATIO : db2linear:min(1):max(MIN_flt)))<:_,_:pow(powlim(power)));

//<:_,_:pow(powlim( prePower)):preRateLim:min(1):max(MIN_flt)

preRateLim = _;//linear2db<: _,( rateLimit(maximum_rate,maximum_rate) ~ _ ):crossfade(ratelimit) : db2linear;

maxGRshaper = _;//max(maxGR);
//maxGRshaper = (1/((1/_*maxGR*2*PI:tanh:/(2*PI))/maxGR)):min(1);

tanshape(amp,x) =(tanh(amp*(x-1)))+1;

//((tanh(amp*((x*2)-1)))/2)+0.5;


curve_pow(fact,x) = ((x*(x>0):pow(p))+(x*-1*(x<=0):pow(p)*-1)) with
{
    p = exp(fact*10*(log(2)));
};

rateLimit(maxRateAttack,maxRateDecay,prevx,x) = prevx+newtangent:min(0)
//:max(maxGR:linear2db)
with {
    tangent       = x- prevx;
    actualTangent  = prevx - prevx';
    avgChange      = abs((actualTangent)-(actualTangent@1)):pow(IMpower):integrate(IM_size):pow(1/IMpower):(SMOOTH(attack, release) ~ _)*decayMult:_+1:pow(decayPower)-1:mymeter;
    newtangent     = select2(tangent>0,minus,plus):max(maxRateAttack*-1):min(maxRateDecay);
    plus           = tangent*(((abs(avgChange)*-1):db2linear));
    minus          = tangent;//*((abs(avgChange)*0.5):db2linear);
       //select2(abs(tangent)>maxRate,tangent,maxRate);
	integrate(size,x) = delaysum(size, x)/size;
    
    delaysum(size) = _ <: par(i,rmsMaxSize, @(i)*(i<size)) :> _;
    };

mymeter = meter_group(_<:(_, ( (vbargraph("[1][unit:dB][tooltip: input level in dB]", 0, 144)))):attach);
COMP = detector:maxGRshaper:(_-maxGR)*(1/(1-maxGR)): curve_pow(curve):tanshape(shape):_*(1-maxGR):_+maxGR:linear2db
<: _,( rateLimit(maxRateAttack,maxRateDecay) ~ _ ):crossfade(ratelimit) : db2linear;//:( rateLimit(maxRate) ~ _ );

blushcomp =_*ingain: (_ <:( crossfade(feedFwBw,_,_),_ : ( COMP , _ ) : gainHiShelfCrossfade(gainHS))~_)*(db2linear(outgain));

//process =blushcomp, blushcomp;

detect= (linear2db :
		THRESH(threshold)
		:RATIO);
        /*:SMOOTH(attack, release) ~ _ );*/

predelay = hslider("[0]predelay[tooltip: ]", maxPredelay , 1, maxPredelay , 1);
//predelay = hslider("[0]predelay[tooltip: ]", 1, 0.0, 24, 0.001)*SR*0.001:int:max(1);
//predelay = 0.5*SR;
//maximumdown needs a power of 2 as a size
//maxPredelay = 4; // = 0.1ms
//maxPredelay = 256; // = 6ms
maxPredelay = 512; // = 12ms
//maxPredelay = 1024; // = 23ms
//maxPredelay = 2048; // = 46ms
//maxPredelay = 8192; // = 186ms

lookaheadLimiter(x,prevgain,prevtotal,prevstart) = 
select2(goingdown,0 ,(prevgain+down)):min(currentup),
//currentup ,
(totaldown),
start
//threshold:meter
with {
    currentLevel = ((abs(x)):linear2db);
    tooBig = currentLevel>threshold;
    notThereYet= prevgain>prevtotal;

    goingdown = (tooBig|notThereYet);
    //prevLin=prevgain:db2linear;
    //down = (totaldown)/predelay;
    down = (prevtotal-prevstart)/(predelay);
    //down = totaldown(x)/predelay;
    totaldown = 
       select2(goingdown, currentup   , newdown  );
    newdown =// (currentLevel+prevgain):THRESH(threshold);
    min(prevtotal,currentdown );
    //select2(0-((currentLevel):THRESH(threshold))<prevtotal,prevtotal,0-((currentlevel):THRESH(threshold)));

    currentdown = 0-((currentLevel):THRESH(threshold));
    currentup =  0-((((abs(x@(predelay))):linear2db)):THRESH(threshold));

    start = select2(totaldown<prevtotal, 0  , select2(prevgain+down<prevtotal,prevstart,prevgain+down));
    
 
    maximumdown = par(i,predelay, currentdown@(i)*(goingdown@(i)*-1+1)  ): seq(j,(log(predelay)/log(2)),par(k,predelay/(2:pow(j+1)),min));

    up = 800/SR;

    tangent     = x- prevx;
    avgChange   = abs((tangent@1)-(tangent@2)):integrate(IM_size)*decayMult:_+1:pow(decayPower)-1;
    newtangent  = select2(tangent>0,minus,plus):max(maxRateAttack*-1):min(maxRateDecay);
    plus        = tangent*((abs(avgChange)*-1):db2linear);
    minus       = tangent;//*((abs(avgChange)*0.5):db2linear);
       //select2(abs(tangent)>maxRate,tangent,maxRate);
	integrate(size,x) = delaysum(size, x)/size;
    
    delaysum(size) = _ <: par(i,rmsMaxSize, @(i)*(i<size)) :> _;
    };




dbmeter =db2linear:meter: linear2db;

autoRate(fast,slow) = auto(fast,slow)~_
with {
auto(fast,slow,prev)= (fast,slow:crossfade(rate));
rate = ratelimit;
};

rateLimiter = (_<: _,(rateLimit(MAX_flt,maxRateDecay) ~ _ ):crossfade(ratelimit));

currentLevel(x) = ((abs(x)):linear2db);
currentdown(x) = 0-((currentLevel(x)):THRESH(threshold));

//serial implementation seems slightly more cpu efficient at high gain reduction,
//but parallel impl

//((tanh((x^36)*6)/tanh(6))*0.5+0.5)*tanh(6*x)/tanh(6)
 attackShaper(x)= ((((tan(x:pow(limPower)*(limPower:pow(0.5)))/tan(limPower:pow(0.5)))*(1-peakRMS))+peakRMS)*tan(limPower:pow(0.5)*x)/tan(limPower:pow(0.5))),x:crossfade(gainHS);

//:pow(limPower)
//: curve_pow(curve)
newLookahead(x) =currentdown(x)<: par(i,maxPredelay, _@(i)*((((i+1+predelay-maxPredelay):max(0))/predelay):attackShaper:min(1))): seq(j,(log(maxPredelay)/log(2)),par(k,maxPredelay/(2:pow(j+1)),min));


/*newLookahead(x) =currentdown(x): seq(i,maxPredelay, currentdown(x)@(i+1)*((i+1+predelay-maxPredelay):max(0)),_: min)/predelay;*/
limiter(x) = newLookahead (x):rateLimiter:db2linear:meter ,x@(maxPredelay-1):*;//gainLowShelfCrossfade(gainHS);
/*limiter(x) = newLookahead (x):rateLimiter:db2linear:meter ,x@(maxPredelay):*;//gainLowShelfCrossfade(gainHS);*/

//limiter(x) = ((lookaheadLimiter(x):(_,_,_))~(_,_,_)):((_<: _,(rateLimit(MAX_flt,maxRateDecay) ~ _ ):autoRate),!,!):db2linear:meter ,x@(predelay):*;//gainLowShelfCrossfade(gainHS);
//limiter(x) = ((lookaheadLimiter(x):(_,_,_))~(_,_,_)):((rateLimit(MAX_flt,maxRateDecay) ~ _ ),!,!):db2linear:meter ,x@(predelay):*;//gainLowShelfCrossfade(gainHS);

lowShelfCurrentDown(x) = ((currentdown(x))/(abs(threshold)+1))*30;
//lowShelfCurrentDown(x) = (0:seq(i,60,((_,(abs(x:low_shelf(-0.5*(i+1),hiShelfFreq))<(threshold:db2linear))):+)))*0.5;

lowShelfLookahead(x) =lowShelfCurrentDown(x)<: par(i,maxPredelay, _@(i)*((((i+1+predelay-maxPredelay):max(0))/predelay):min(1))): seq(j,(log(maxPredelay)/log(2)),par(k,maxPredelay/(2:pow(j+1)),min));

lowShelfLimiter(x) = (x@(maxPredelay-1)):low_shelf((lowShelfLookahead (x):rateLimiter:dbmeter) ,hiShelfFreq);//gainLowShelfCrossfade(gainHS);

//process = blushcomp,blushcomp;
//process = lowShelfLimiter,lowShelfLimiter;
process = limiter,limiter;
//process = limiter,(_<:limiter,((RMS(16),RMS(rms_speed):-):meter));
//process = highpass(3 ,hiShelfFreq);

//process(x) = lowShelfCurrentDown(x) :dbmeter ;
//.70710713 rms
//.26 smr
