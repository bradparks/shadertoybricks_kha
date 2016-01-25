// Created by inigo quilez - iq/2016
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0
// https://www.shadertoy.com/view/MddGzf
// Adapted to Kha by Lubos Lenco

//
// Gameplay computation.
//
// The gameplay buffer is 14x14 pixels. The whole game is run/played for each one of these
// pixels. A filter the end of the shader takes only the bit  of infomration that needs 
// to be stored each texl of the game-logic texture.

#ifdef GL_ES
precision mediump float;
#endif

// storage register/texel addresses
const vec2 txBallPosVel = vec2(0.0,0.0);
const vec2 txPaddlePos  = vec2(1.0,0.0);
const vec2 txPoints     = vec2(2.0,0.0);
const vec2 txState      = vec2(3.0,0.0);
const vec2 txLastHit    = vec2(4.0,0.0);
const vec4 txBricks     = vec4(0.0,1.0,13.0,12.0);

const float ballRadius = 0.035;
const float paddleSize = 0.30;
const float paddleWidth = 0.06;
const float paddlePosY  = -0.90;
const float brickW = 2.0/13.0;
const float brickH = 1.0/15.0;

const float gameSpeed = 3.0;
const float inputSpeed = 2.0;

const float KEY_SPACE = 32.5/256.0;
const float KEY_LEFT  = 37.5/256.0;
const float KEY_UP    = 38.5/256.0;
const float KEY_RIGHT = 39.5/256.0;
const float KEY_DOWN  = 40.5/256.0;

uniform sampler2D iChannel0;
uniform vec3 iChannelResolution0;
uniform float iGlobalTime;
uniform int iFrame;
uniform vec3 iResolution;
uniform vec4 iMouse;
varying vec2 fragCoord;

//----------------------------------------------------------------------------------------------

float isInside( vec2 p, vec2 c ) {
    vec2 d = abs(p-0.5-c) - 0.5;
    return -max(d.x,d.y);
}
float isInside( vec2 p, vec4 c ) {
    vec2 d = abs(p-0.5-c.xy-c.zw*0.5) - 0.5*c.zw - 0.5;
    return -max(d.x,d.y);
}

float hash1( float n ) { return fract(sin(n)*138.545); }

// intersect a disk sweept a linear segment with a line/plane. 
float iPlane( vec2 ro, vec2 rd, float rad, vec3 pla )
{
    float a = dot( rd, pla.xy );
    if( a>0.0 ) return -1.0;
    float t = (rad - pla.z - dot(ro,pla.xy)) / a;
    if( t>=1.0 ) t=-1.0;
    return t;
}

// intersect a disk sweept a linear segment with a box 
vec3 iBox( vec2 ro, vec2 rd, float rad, vec2 bce, vec2 bwi ) 
{
    vec2 m = 1.0/rd;
    vec2 n = m*(ro - bce);
    vec2 k = abs(m)*(bwi+rad);
    vec2 t1 = -n - k;
    vec2 t2 = -n + k;
    float tN = max( t1.x, t1.y );
    float tF = min( t2.x, t2.y );
    if( tN > tF) return vec3(-1.0);
    if (tF < 0.0) return vec3(-1.0);
    if( tN>=1.0 ) return vec3(-1.0);
    vec2 nor = -sign(rd)*step(t1.yx,t1.xy);
    return vec3( tN, nor );
}

//----------------------------------------------------------------------------------------------

vec4 loadValue( vec2 re )
{
    //return texture2D( iChannel0, (0.5+re) / iChannelResolution0.xy, -100.0 );
    //return vec4(0.0);
    return texture2D(iChannel0, ((vec2(0.5, 0.5) + re) / vec2(iChannelResolution0[0], iChannelResolution0[1])));
}

vec4 storeValue( vec2 re, vec4 va, vec4 fragColor, vec2 fragCoord )
{
    vec2 param_236;
    vec2 param_238;
    param_236 = fragCoord;
    param_238 = re;
    // Merge 243 0
    if ((isInside(param_236, param_238) > 0.0)) // true: 242 false: 243
    { // Label 242
        return va;
    } // Label 243
    return fragColor;

    // if ( isInside(fragCoord,re) > 0.0 ) {
    //     return va;
    // } 
    // return fragColor;
}
vec4 storeValue( vec4 re, vec4 va, vec4 fragColor, vec2 fragCoord )
{
    vec2 param_252;
    vec4 param_254;
    param_252 = fragCoord;
    param_254 = re;
    // Merge 259 0
    if ((isInside(param_252, param_254) > 0.0)) // true: 258 false: 259
    { // Label 258
        return va;
    } // Label 259
    return fragColor;

    // if ( isInside(fragCoord,re) > 0.0 ) {
    //     return va;
    // } 
    // return fragColor;
}

//----------------------------------------------------------------------------------------------

void kore()
{
    vec2 fc = fragCoord;
    fc.x *= iChannelResolution0.x;
    fc.y *= iChannelResolution0.y;

    // don't compute gameplay outside of the data area
    if( fc.x > 14.0 ) discard;
    if( fc.y>14.0 ) discard;
    
    //---------------------------------------------------------------------------------   
    // load game state
    //---------------------------------------------------------------------------------
    vec4  balPosVel = loadValue( txBallPosVel );
    float paddlePos = loadValue( txPaddlePos ).x;
    float points    = loadValue( txPoints ).x;
    float state     = loadValue( txState ).x;
    vec3  lastHit   = loadValue( txLastHit ).xyz;        // paddle, brick, wall
    vec2  brick     = loadValue( fc.xy-0.5 ).xy;  // visible, hittime
    
    //---------------------------------------------------------------------------------
    // reset
    //---------------------------------------------------------------------------------
    if( iFrame==0 ) state = -1.0;
    
    if( state < -0.5 )
    {
        state = 0.0;
        balPosVel = vec4(0.0,paddlePosY+ballRadius+paddleWidth*0.5+0.001, 0.6,1.0);
        paddlePos = 0.0;
        points = 0.0;
        state = 0.0;
        brick = vec2(1.0,-5.0);
        lastHit = vec3(-1.0);
        
        
        if( fc.x<1.0 )
        {
            brick.x = 0.0;
            brick.y = -10.0;
        }
        if (fc.x>12.0)
        {
             brick.x = 0.0;
            brick.y = -10.0;
        }
        

    }

    //---------------------------------------------------------------------------------
    // do game
    //---------------------------------------------------------------------------------

    // game over (or won), wait for space key press to resume
    if( state > 0.5 )
    {
        // float pressSpace = texture2D( iChannel1, vec2(KEY_SPACE,0.25) ).x;
        // if( pressSpace>0.5 )
        // {
        //     state = -1.0;
        // }
        if( iMouse.w > 0.01 )
        {
            state = -1.0;
        }
    }
    
    // if game mode (not game over), play game
    else if( state < 0.5 ) 
    {

        //-------------------
        // paddle
        //-------------------
        float oldPaddlePos = paddlePos;
        if( iMouse.w>0.01 )
        {
            // move with mouse
            paddlePos = (-1.0 + 2.0*iMouse.x/iResolution.x)*iResolution.x/iResolution.y;
        }
        // else
        // {
        //     // move with keyboard
        //     float moveRight = texture2D( iChannel1, vec2(KEY_RIGHT,0.25) ).x;
        //     float moveLeft  = texture2D( iChannel1, vec2(KEY_LEFT,0.25) ).x;
        //     paddlePos += 0.02*inputSpeed*(moveRight - moveLeft);
        // }
        paddlePos = clamp( paddlePos, -1.0+0.5*paddleSize+paddleWidth*0.5, 1.0-0.5*paddleSize-paddleWidth*0.5 );

        float moveTotal = sign( paddlePos - oldPaddlePos );

        //-------------------
        // ball
        //-------------------
        float dis = 0.01*gameSpeed;
        
        
        int a = 0;
        // do up to 3 sweep collision detections (usually 0 or 1 will happen only)
        for( int j=0; j<3; j++ )
        {
            vec3 oid = vec3(-1.0);
            vec2 nor;
            float t = 1000.0;

            // test walls
            const vec3 pla1 = vec3(-1.0, 0.0,1.0 ); 
            const vec3 pla2 = vec3( 1.0, 0.0,1.0 ); 
            const vec3 pla3 = vec3( 0.0,-1.0,1.0 ); 
            float t1 = iPlane( balPosVel.xy, dis*balPosVel.zw, ballRadius, pla1 );
            if( t1>0.0         ) { t=t1; nor = pla1.xy; oid.x=1.0; }
            float t2 = iPlane( balPosVel.xy, dis*balPosVel.zw, ballRadius, pla2 );
            if( t2>0.0)
                if (t2<t )
                    { t=t2; nor = pla2.xy; oid.x=2.0; }
            float t3 = iPlane( balPosVel.xy, dis*balPosVel.zw, ballRadius, pla3 );
            if( t3>0.0)
                if (t3<t )
                    { t=t3; nor = pla3.xy; oid.x=3.0; }
            
            // test paddle
            vec3  t4 = iBox( balPosVel.xy, dis*balPosVel.zw, ballRadius, vec2(paddlePos,paddlePosY), vec2(paddleSize*0.5,paddleWidth*0.5) );
            if( t4.x>0.0)
                if(t4.x<t ) { t=t4.x; nor = t4.yz; oid.x=4.0;  }
            
            // test bricks
            vec2 idr = floor( vec2( (1.0+balPosVel.x)/brickW, (1.0-balPosVel.y)/brickH) );
            vec2 vs = sign(balPosVel.zw);
            for( int j=0; j<3; j++ )
            for( int i=0; i<3; i++ )
            {
                vec2 id = idr + vec2( vs.x*float(i),-vs.y*float(j));
                if( id.x>=0.0)
                if (id.x<13.0)
                if (id.y>=0.0)
                if (id.y<12.0 )
                {
                    float brickHere = texture2D( iChannel0, (0.5+txBricks.xy+id)/iChannelResolution0.xy, -100.0 ).x;
                    if( brickHere>0.5 )
                    {
                        vec2 ce = vec2( -1.0 + float(id.x)*brickW + 0.5*brickW,
                                         1.0 - float(id.y)*brickH - 0.5*brickH );
                        vec3 t5 = iBox( balPosVel.xy, dis*balPosVel.zw, ballRadius, ce, 0.5*vec2(brickW,brickH) );
                        if( t5.x>0.0) {
                            if (t5.x<t )
                            {
                                oid = vec3(5.0,id);
                                t = t5.x;
                                nor = t5.yz;
                            }
                        }
                    }
                }
            }
            
            // no collisions
            if( oid.x<0.0 ) a = 1; //break;

            if (a == 0) {
                // bounce
                balPosVel.xy += t*dis*balPosVel.zw;
                dis *= 1.0-t;
                
                // did hit walls
                if( oid.x<3.5 )
                {
                    balPosVel.zw = reflect( balPosVel.zw, nor );
                    lastHit.z = iGlobalTime;
                }
                // did hit paddle
                else if( oid.x<4.5 )
                {
                    balPosVel.zw = reflect( balPosVel.zw, nor );
                    // borders bounce back
                         if( balPosVel.x > (paddlePos+paddleSize*0.5) ) balPosVel.z =  abs(balPosVel.z);
                    else if( balPosVel.x < (paddlePos-paddleSize*0.5) ) balPosVel.z = -abs(balPosVel.z);
                    balPosVel.z += 0.37*moveTotal;
                    balPosVel.z += 0.11*hash1( float(iFrame)*7.1 );
                    balPosVel.z = clamp( balPosVel.z, -0.9, 0.9 );
                    balPosVel.zw = normalize(balPosVel.zw);
                    
                    // 
                    lastHit.x = iGlobalTime;
                    lastHit.y = iGlobalTime;
                }
                // did hit a brick
                else if( oid.x<5.5 )
                {
                    balPosVel.zw = reflect( balPosVel.zw, nor );
                    lastHit.y = iGlobalTime;
                    points += 1.0;
                    if( points>131.5 )
                    {
                        state = 2.0; // won game!
                    }

                    if( isInside(fc,txBricks.xy+oid.yz) > 0.0 )
                    {
                        brick = vec2(0.0, iGlobalTime);
                    }
                }
            }
        }
        
        balPosVel.xy += dis*balPosVel.zw;
        
        // detect miss
        if( balPosVel.y<-1.0 )
        {
            state = 1.0; // game over
        }
    }
    
	//---------------------------------------------------------------------------------
	// store game state
	//---------------------------------------------------------------------------------
    vec4 fragColor = vec4(0.0);
 
    fragColor = storeValue( txBallPosVel, vec4(balPosVel),             fragColor, fc );
    fragColor = storeValue( txPaddlePos,  vec4(paddlePos,0.0,0.0,0.0), fragColor, fc );
    fragColor = storeValue( txPoints,     vec4(points,0.0,0.0,0.0),    fragColor, fc );
    fragColor = storeValue( txState,      vec4(state,0.0,0.0,0.0),     fragColor, fc );
    fragColor = storeValue( txLastHit,    vec4(lastHit,0.0),           fragColor, fc );
    fragColor = storeValue( txBricks,     vec4(brick,0.0,0.0),         fragColor, fc );

    gl_FragColor = fragColor;
}