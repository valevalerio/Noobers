// brain

#include "/Entities/Common/Emotes/EmotesCommon.as"

namespace Strategy
{
	enum strategy_type
	{
		idle = 0,
		chasing,
		attacking,
		retreating
	}
}

void InitBrain(CBrain@ this)
{
	CBlob @blob = this.getBlob();
	blob.set_Vec2f("last pathing pos", Vec2f_zero);
	blob.set_u8("strategy", Strategy::idle);
	this.getCurrentScript().removeIfTag = "dead";   //won't be removed if not bot cause it isnt run

	if (!blob.exists("difficulty"))
	{
		blob.set_s32("difficulty", 15); // max
	}
	
	// get a target so we start walking right away from the tent.
	//SearchTarget(CBrain@ this, const bool seeThroughWalls = false, const bool seeBehindBack = true)
	
	print("Brain initialized.");

	// set an aim position at random, and go there
//	blob.setAimPos(Vec2f(XORRandom(int(map.tilemapwidth * map.tilesize)), XORRandom(int(map.tilemapheight * map.tilesize))));	
//	SearchTarget(this, true, true);
	
//	CBlob@ oldTarget = target;
//	@target = getNewTarget(this, blob, true, true);
//	this.SetTarget(target);	
	
//		getBlobsByTag("player", @players);
	/*CBlob@[] flags;
	getBlobsByTag("player", @flags);
	//printInt("flags.length", flags.length);
		for (int i=0; i<flags.length; ++i) { 
			if ( flags[i].getTeamNum() != blob.getTeamNum() ) { this.SetTarget(flags[i]);	}		
		}*/
		
			CBlob@[] flags2;	getBlobsByName("flag_base", @flags2);
			if ( flags2.length > 0 ) {
				for (int i=0; i<flags2.length; ++i) { 
					if ( flags2[i].getTeamNum() != blob.getTeamNum()  ) { 			
						blob.getBrain().SetTarget(flags2[i]);			
						print("Walking to enemy flag");						
						}
					}

			}	

//	JustGo(blob, flags[0]);	
	
	/*
	
		Every situation has variables, like distanceToTarget.

		Say we want to have a self learning algorithm determining what the optimal action is, depending on the distance to the target.

		actions = [ attack, chase, retreat ]

		distanceStates = [ far, medium, close ]
		targetClass = [ knight, archer, builder ]

		for all distanceStates	
			if distanceToTarget == distanceStates[i]
				if targetClass == knight
					
					
					
				if targetClass == archer
				if targetClass == builder								

	CBlob@[] flags;getBlobsByTag("flag", @flags);
	
	if ( flags.length > 0 ) { blob.setTarget(flags[0]); }
	
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < flags.length; i++)
	{	
	}

	CBlob@[] flags;getBlobsByTag("flag", @flags); 
	JustGo(blob, flags[0]);
	
	*/
	
	
}

CBlob@ getNewTarget(CBrain@ this, CBlob @blob, const bool seeThroughWalls = true, const bool seeBehindBack = true)
{
	CBlob@[] players;
	getBlobsByTag("player", @players);
	Vec2f pos = blob.getPosition();
	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ potential = players[i];
		Vec2f pos2 = potential.getPosition();
		const bool isBot = blob.getPlayer() !is null && blob.getPlayer().isBot();
		if (potential !is blob && blob.getTeamNum() != potential.getTeamNum()
		        && (pos2 - pos).getLength() < 600.0f
		        && (isBot || seeBehindBack || Maths::Abs(pos.x - pos2.x) < 40.0f || (blob.isFacingLeft() && pos.x > pos2.x) || (!blob.isFacingLeft() && pos.x < pos2.x))
		        && (isBot || seeThroughWalls || isVisible(blob, potential))
		        && !potential.hasTag("dead") && !potential.hasTag("migrant")
		   )
		{
			blob.set_Vec2f("last pathing pos", potential.getPosition());
			return potential;
		}
	}
	return null;
}

void Repath(CBrain@ this)
{
	this.SetPathTo(this.getTarget().getPosition(), false);
}

bool isVisible(CBlob@blob, CBlob@ target)
{
	Vec2f col;
	return !getMap().rayCastSolid(blob.getPosition(), target.getPosition(), col);
}

bool isVisible(CBlob@ blob, CBlob@ target, f32 &out distance)
{
	Vec2f col;
	bool visible = !getMap().rayCastSolid(blob.getPosition(), target.getPosition(), col);
	distance = (blob.getPosition() - col).getLength();
	return visible;
}

bool JustGo(CBlob@ blob, CBlob@ target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f point = target.getPosition();
	const f32 horiz_distance = Maths::Abs(point.x - mypos.x);

	if (horiz_distance > blob.getRadius() * 0.75f)
	{
		if (point.x < mypos.x)
		{
			blob.setKeyPressed(key_left, true);
		}
		else
		{
			blob.setKeyPressed(key_right, true);
		}

		if (point.y + getMap().tilesize * 0.7f < mypos.y && (target.isOnGround() || target.getShape().isStatic()))  	 // dont hop with me
		{
			blob.setKeyPressed(key_up, true);
		}

		if (blob.isOnLadder() && point.y > mypos.y)
		{
			blob.setKeyPressed(key_down, true);
		}

		return true;
	}

	return false;
}

void JumpOverObstacles(CBlob@ blob)
{
	
	blob.setHeadNum(3);
	
	/* create a recurring search for target */
//	if (XORRandom(50) <= 5){	
		CBlob@[] flags;
		getBlobsByTag("player", @flags);
		bool picked = false;
			for (int i=0; i<flags.length; ++i) { 
				if ( flags[i].getTeamNum() != blob.getTeamNum()  ) { 
				

					// calculate distance x, and y
					int tdx = 0;
					int tdy = 0;
					
					tdx = blob.getPosition().x - flags[i].getPosition().x;
					tdy = blob.getPosition().x - flags[i].getPosition().y;					
					
					// if the enemy is close, pick it as a target.
					bool pick = false;
					if ( tdx < 0 && tdx > -170 ) { pick = true; }
					if ( tdx > 0 && tdx < 170 ) { pick = true; }					
					if ( pick == true ) {
						blob.getBrain().SetTarget(flags[i]);		
						picked = true;				
					} 
					
					// if not necessarilty close, throw up dice to see if we want to target this player
					else if ( XORRandom(50) < 2 ){
						blob.getBrain().SetTarget(flags[i]);		
						picked = true;						
					}

				
			}	
		// if we did not pick a target, walk to the first enemy tent we can find
		if ( picked == false ) {


			CBlob@[] flags2;	getBlobsByName("tent", @flags2);// if ( flags2.length > 0 ) {printInt("d",flags2.length);}
			if ( flags2.length > 0 ) {
				for (int i=0; i<flags2.length; ++i) { 
					if ( flags2[i].getTeamNum() != blob.getTeamNum()  ) { 			
						blob.getBrain().SetTarget(flags2[i]);			
						//print("Walking to enemy flag");						
						}
					}

			}
		
		}
	}
	
//	CBlob@[] flags2; getBlobsByName("flag_base", @flags2); printInt("flagbase", flags2.length);
	

	// push! stop at nothing! (unless retreating)
	bool targetToLeft = false;
	bool goback = false;
	goback = blob.get_bool("goback");
	
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = 	blob.getBrain().getTarget().getPosition();
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	
	if ( goback == true ) {
		// reduce stuck timer
		int stuck_t = blob.get_s32("stuck_t");
		stuck_t -= 1;
		blob.set_s32("stuck_t", stuck_t);
			
		// if stuck timer < 1, turn off retreat
		if ( stuck_t < 1 ) {
			blob.set_bool("goback", false);
			print("goback OFF");
		}		
		
		
		if (targetPos.x < mypos.x)
		{
			targetToLeft = true;
			blob.setKeyPressed(key_right, true);
		}
		else
		{
			blob.setKeyPressed(key_left, true);
		}	
	}
	else {
		if (targetPos.x < mypos.x)
		{
			targetToLeft = true;
			blob.setKeyPressed(key_left, true);
		}
		else
		{
			blob.setKeyPressed(key_right, true);
		}
	}




	if (targetPos.y + getMap().tilesize < mypos.y &&  blob.get_s32("bombtimer") == 0  )
	{
		blob.setKeyPressed(key_up, true);
	}
		
		
	// calculate distance x to target
	int tdx2 = 0;
	tdx2 = blob.getPosition().x - blob.getBrain().getTarget().getPosition().x;						
	// if the enemy is close, pick it as a target.
	bool pick2 = false;
	if ( tdx2 < 0 && tdx2 > -190 ) { pick2 = true; }
	if ( tdx2 > 0 && tdx2 < 190 ) { pick2 = true; }					
						
		

	// calculate max x distance to own flag
	bool pick3 = false;	// are we far enough from the flag?
	int minDistanceFromFlag = 110;
	int tdx3 = 0;
	int count = 0;
	
		// for all flags
			CBlob@[] flags2;	getBlobsByName("flag_base", @flags2);
			if ( flags2.length > 0 ) {
				for (int i=0; i<flags2.length; ++i) { 
					// get distance to blob
					tdx3 = blob.getPosition().x - flags2[i].getPosition().x;											
				
					// if it is one of our own flags
					if ( flags2[i].getTeamNum() == blob.getTeamNum()  ) { 			

							// if distance smaller tha
								if ( tdx3 < 0 && tdx3 < -(minDistanceFromFlag) ) { count++;  }
								if ( tdx3 > 0 && tdx3 > minDistanceFromFlag ) { count++;   }			

						}
					}
					
					// if all flags are counted as being at least minDistance away, set flag to tue
					if ( count >= flags2.length/2 ) {
//						printInt("FAR FROM FLAG", count);
						pick3 = true;	
						}

			}	

	/* create bomb with random direction if enemy close and we are not currently throwing/bomjumping */
	if ( pick3 == true ) {
		if ( pick2 == true && blob.get_s32("bombtimer") <= 0){


 		
		 CBlob@ bomb = server_CreateBlob("bomb", blob.getTeamNum(), blob.getPosition());  		

		bool throwing = false;

		// hold the newly created bomb
		blob.set_s32("bombtimer", 130); // max
		blob.server_Pickup(bomb);

		// do we wanna throw it?
		if (XORRandom(100) > 70 ) {
			blob.set_bool("throwing", true);
		}

		// reset the retreat vars 
		blob.set_bool("goback", false);
		blob.set_s32("stuck_t", 0);


	}
	}


//AddBot("Brain");AddBot("Brain");

	// remember previous position
	int y_old = blob.get_s32("y");
	blob.set_s32("y_old", y_old);
	
	int x_old = blob.get_s32("x");
	blob.set_s32("x_old", x_old);
		
	int y_new = blob.getPosition().y;
	int x_new = blob.getPosition().x;	
	// calculate difference in position with last remembered position.	
	int dy = y_new - y_old;
	int dx = x_new - x_old;
//	printInt("dy", dy);
//	printInt("dx", dx);	
	blob.set_s32("y", y_new);	
	blob.set_s32("x", x_new);		
	
	int max_dy = 2;
	int min_dx = 1;
	int max_stuck = 150;

	// if difference in y > max and going down
	if ( dy > max_dy ) {
			// glide
			// aim up
			Vec2f aimpos = blob.getPosition();
			aimpos.y -= 100;
			blob.setAimPos(aimpos);				
			blob.setKeyPressed(key_action2, true);							
	}
	
	// if difference in x < minimum
	if ( dx == 0 && blob.get_bool("goback") == false ) {
		// we havent moved much, add to the "probably stuck" timer
		int pstuck_t = 0;
		pstuck_t = blob.get_s32("stuck_t");
		pstuck_t += 1;
		blob.set_s32("stuck_t", pstuck_t);
		//printInt("pstuck_t", pstuck_t);
		
		if ( pstuck_t > max_stuck + XORRandom(12) ) {
			// retreat.
			print("MAX STUCK, moving back");
			blob.set_s32("stuck_t", pstuck_t);			
			blob.set_bool("goback", true);
		}	
		
	}

	
	// bomb jump timer and the timed bomb jumping behaviour
	if ( blob.get_s32("bombtimer") > 0 ) {
	
		// tick down
		blob.set_s32("bombtimer", blob.get_s32("bombtimer")-1);

		// if bombjumping	
		if ( blob.get_bool("throwing") == false ) {
			// aim toward the bomb position
			Vec2f aimpos = blob.getPosition();
			aimpos.y += 100;
			blob.setAimPos(aimpos);		

			// jumping time
			if ( blob.get_s32("bombtimer") < 15 ) {
				blob.setKeyPressed(key_action2, true);			
				// drop the bomb
				blob.DropCarried();
			
			}		
				
			// jump above the bomb
			if ( blob.get_s32("bombtimer") < 20 ) {
				blob.setKeyPressed(key_up, true);			

			}
			else {
				blob.setKeyPressed(key_up, false);					
			}

		}
		// if throwing
		else {
			blob.setKeyPressed(key_action2, true);				
			if ( blob.get_s32("bombtimer") < 50 ) {		
				CBlob@ bomb = blob.getCarriedBlob();
				blob.DropCarried();			
				if ( bomb != null ) {
				if ( targetToLeft == true ) {
					bomb.setVelocity(Vec2f( (-10.0f + XORRandom(8) ), -10.0f));
					 }
				else {
					 bomb.setVelocity(Vec2f( (10.0f - XORRandom(8) ), -10.0f));		
				}		
				// aim toward the bomb position
				Vec2f aimpos = bomb.getPosition();
				blob.setAimPos(aimpos);				 
				}						
				
			}
			if ( blob.get_s32("bombtimer") < 5 ) {		
				blob.set_bool("throwing", false);
			}			
		}		


		return;			
		
	}
	// this was the default behaviour of this method. it jumps us over small obstacles.
	// i have reduced the probability of it occurring.
	else { //if ( XORRandom(150) == 0  ){

		Vec2f pos = blob.getPosition();
		const f32 radius = blob.getRadius();

		if (blob.isOnWall())
		{
			blob.setKeyPressed(key_up, true);
			blob.setKeyPressed(key_action2, true);		

		}
		else if (!blob.isOnLadder())
			if ((blob.isKeyPressed(key_right) && (getMap().isTileSolid(pos + Vec2f(1.3f * radius, radius) * 1.0f) || blob.getShape().vellen < 0.1f)) ||
					(blob.isKeyPressed(key_left)  && (getMap().isTileSolid(pos + Vec2f(-1.3f * radius, radius) * 1.0f) || blob.getShape().vellen < 0.1f)))
			{
				blob.setKeyPressed(key_up, true);
			}
	
	}
	
}

void DefaultChaseBlob(CBlob@ blob, CBlob @target)
{
	CBrain@ brain = blob.getBrain();
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	Vec2f targetVector = targetPos - myPos;
	f32 targetDistance = targetVector.Length();
	// check if we have a clear area to the target
	bool justGo = false;

	if (targetDistance < 120.0f)
	{
		Vec2f col;
		if (isVisible(blob, target))
		{
			justGo = true;
		}
	}

	// repath if no clear path after going at it
	if (XORRandom(50) == 0 && (blob.get_Vec2f("last pathing pos") - targetPos).getLength() > 50.0f)
	{
		Repath(brain);
		blob.set_Vec2f("last pathing pos", targetPos);
	}

	const bool stuck = brain.getState() == CBrain::stuck;

	const CBrain::BrainState state = brain.getState();
	{
		if (!isFriendAheadOfMe(blob, target))
		{
			if (state == CBrain::has_path)
			{
				brain.SetSuggestedKeys();  // set walk keys here
			}
			else
			{
				JustGo(blob, target);
			}
		}

		// printInt("state", this.getState() );
		switch (state)
		{
			case CBrain::idle:
				Repath(brain);
				break;

			case CBrain::searching:
				//if (sv_test)
				//	set_emote( blob, Emotes::dots );
				break;

			case CBrain::stuck:
				Repath(brain);
				break;

			case CBrain::wrong_path:
				Repath(brain);
				break;
		}
	}

	// face the enemy
	blob.setAimPos(target.getPosition());

	// jump over small blocks
	JumpOverObstacles(blob);
}

bool DefaultRetreatBlob(CBlob@ blob, CBlob@ target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f point = target.getPosition();
	if (point.x > mypos.x)
	{
		blob.setKeyPressed(key_left, true);
	}
	else
	{
		blob.setKeyPressed(key_right, true);
	}

	if (mypos.y - blob.getRadius() > point.y)
	{
		blob.setKeyPressed(key_up, true);
	}

	if (blob.isOnLadder() && point.y < mypos.y)
	{
		blob.setKeyPressed(key_down, true);
	}

	JumpOverObstacles(blob);

	return true;
}

void SearchTarget(CBrain@ this, const bool seeThroughWalls = false, const bool seeBehindBack = true)
{
	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// search target if none
	if (target is null)
	{
		CBlob@ oldTarget = target;
		@target = getNewTarget(this, blob, seeThroughWalls, seeBehindBack);
		this.SetTarget(target);

		if (target !is oldTarget)
		{
			onChangeTarget(blob, target, oldTarget);
		}
	}

	
}

void onChangeTarget(CBlob@ blob, CBlob@ target, CBlob@ oldTarget)
{
	// !!!
	if (oldTarget is null)
	{
		set_emote(blob, Emotes::attn, 1);
	}
}

bool LoseTarget(CBrain@ this, CBlob@ target)
{
	if (XORRandom(5) == 0 && target.hasTag("dead"))
	{
		@target = null;
		this.SetTarget(target);
		return true;
	}
	return false;
}

void Runaway(CBlob@ blob, CBlob@ target)
{
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	if (target.getPosition().x > blob.getPosition().x)
	{
		blob.setKeyPressed(key_left, true);
	}
	else
	{
		blob.setKeyPressed(key_right, true);
	}
}

void Chase(CBlob@ blob, CBlob@ target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	blob.setKeyPressed(key_left, false);
	blob.setKeyPressed(key_right, false);
	if (targetPos.x < mypos.x)
	{
		blob.setKeyPressed(key_left, true);
	}
	else
	{
		blob.setKeyPressed(key_right, true);
	}

	if (targetPos.y + getMap().tilesize < mypos.y)
	{
		blob.setKeyPressed(key_up, true);
	}
}

bool isFriendAheadOfMe(CBlob @blob, CBlob @target, const f32 spread = 70.0f)
{
	// optimization
	if ((getGameTime() + blob.getNetworkID()) % 10 > 0 && blob.exists("friend ahead of me"))
	{
		return blob.get_bool("friend ahead of me");
	}

	CBlob@[] players;
	getBlobsByTag("player", @players);
	Vec2f pos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ potential = players[i];
		Vec2f pos2 = potential.getPosition();
		if (potential !is blob && blob.getTeamNum() == potential.getTeamNum()
		        && (pos2 - pos).getLength() < spread
		        && (blob.isFacingLeft() && pos.x > pos2.x && pos2.x > targetPos.x) || (!blob.isFacingLeft() && pos.x < pos2.x && pos2.x < targetPos.x)
		        && !potential.hasTag("dead") && !potential.hasTag("migrant")
		   )
		{
			blob.set_bool("friend ahead of me", true);
			return true;
		}
	}
	blob.set_bool("friend ahead of me", false);
	return false;
}

void FloatInWater(CBlob@ blob)
{
	if (blob.isInWater())
	{
		blob.setKeyPressed(key_up, true);
	}
}

void RandomTurn(CBlob@ blob)
{
	if (XORRandom(4) == 0)
	{
		CMap@ map = getMap();
		blob.setAimPos(Vec2f(XORRandom(int(map.tilemapwidth * map.tilesize)), XORRandom(int(map.tilemapheight * map.tilesize))));
	}
}
