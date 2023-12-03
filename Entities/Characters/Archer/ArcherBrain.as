// Archer brain

#define SERVER_ONLY

#include "BrainCommon.as"
#include "ArcherCommon.as"
#include "/Entities/Common/Emotes/EmotesCommon.as"
#include "RidgeRegressorAS.as"
#include "NN.as"
array<NeuralNetwork@> Minds(20);
array<Vec2f> targets(20,Vec2f_zero);

array<float> fitnessValues(20,0);

array<float> currentAngle(20,0);
array<float> goodArrows(20,0);
array<float> arrowsShot(20,0);

float PI = 3.1415927;
float EulerNum = 2.7182818284;
float constGravity = 9.81;

float cosDist(Vec2f a1,Vec2f a2){
	float cd = (a1.x*a2.x + a1.y*a2.y)/(a1.Length()*a2.Length());
	return cd;
}
float cosh(float x)
{
	return 0.5*(Maths::Pow(EulerNum,x)+Maths::Pow(EulerNum,-x));
}
float arccosh(float x)
{
	return Maths::Log(x + Maths::Pow(x*x - 1.0,0.5f));
}

array<float> enanchedInput(Vec2f Pos,Vec2f Vel)
{
	array<float> res(8);
	res[0]=Pos.x;
	res[1]=Pos.y;
	res[2]=Vel.x;
	res[3]=Vel.y;
	res[4]=Maths::ATan2(Vel.x,Vel.y);
	res[5]=Maths::Sin(res[4]);
	res[6]=Maths::Cos(res[4]);
	res[7]=Vel.Length();
	return res;
}

int myAtoi(string num){
	return parseInt(num.substr(2,-1));
}

array<float> gatherInput(CBlob@ blob,CBlob@ target,int IDXFORPRINTS){
	//////////////////////////////
	////////INPUTS////////////////
	//////////////////////////////
	int nrays = 3;
	array<float> inpt4NN(nrays);
	array<string> inptNames(nrays,"");
	float nintyRad = PI/2.0;
	float angleStep = PI/(nrays*1.0)*(2.0/3.0);
	Vec2f pos1 = blob.getPosition()+Vec2f(blob.isFacingLeft() ? 2 : -2, -2);
	float c=0;
	float customAngle = nintyRad+angleStep*c;
	Vec2f otherP;
	bool obstructed = false;
	float theta;
	Vec2f Vel = (blob.getAimPos()-blob.getPosition());
	theta = Maths::ATan2(Vel.x,-Vel.y)-(PI);
	for (int c=-nrays/2;c<nrays/2+1;c++)
	{
		customAngle = nintyRad+angleStep * (c)+theta;
		otherP.x = Maths::Cos(customAngle);
		otherP.y = Maths::Sin(customAngle);
		otherP = otherP*50.0;
		obstructed = getMap().rayCastSolid(pos1, pos1+otherP, Vec2f_zero);
		inpt4NN[c+(nrays/2)] = obstructed ? 1.0 : 0.0;
		inptNames[c+(nrays/2)] = "Ray"+c;
	}

	/////////////////
	/////////////////
	//Trajectories distancies //

	float a;
	array<float> targDist(3,1000);
	Vec2f targetPos = target.getPosition();
	array<double> predictedOutput(4);
	float min_dist=1000.0,currDist;
	Vec2f minDistPoint;
	array<Vec2f> midPoints(3);
	bool raySolid=false;
	for (float j=0.0;j<=2.0;j+=1.0)
	{
		min_dist=1000.0;
		raySolid=false;
		
		a = 17.59*(j==0.0 ? 1.0 :
						(j==1.0 ? (4.0f / 5.0f) : (1.0f / 3.0f) )
						);
		//REGRESSOR INPUT/OUTUPUT	
		Vec2f maxVel = (blob.getAimPos()-blob.getPosition());
		if (maxVel.Length()>0.0)
			maxVel = maxVel*(a/maxVel.Length());
		array<float> inpu ={0,0,maxVel.x,maxVel.y};
		for (int k=0;k<4;k++)
				predictedOutput[k]=inpu[k];
		int i=0;
		while(i<100 and !raySolid)
		{
			i+=1;
			inpu = enanchedInput(Vec2f(inpu[0],inpu[1]),
								Vec2f(inpu[2],inpu[3]));
			
			predictedOutput = predict(inpu[0],inpu[1],inpu[2],inpu[3],inpu[4],inpu[5],inpu[6],inpu[7]);
			
			//print("inpu "+Array2String(inpu)+" output "+Array2String(predictedOutput));
			midPoints[0] = pos1+Vec2f(inpu[0],inpu[1]);
			for (int k=0;k<4;k++)
				inpu[k]=predictedOutput[k];
			midPoints[2] = pos1+Vec2f(predictedOutput[0],predictedOutput[1]);
			midPoints[1] = midPoints[0]+(midPoints[2]-midPoints[0])/2.0;
			raySolid = getMap().rayCastSolid(midPoints[0],midPoints[1], Vec2f())
					and getMap().rayCastSolid(midPoints[1],midPoints[2], Vec2f());

			for (int mp=0;mp<3;mp++){
				currDist = (targetPos-midPoints[0]).Length();
				if (currDist<min_dist){
					min_dist=currDist;
					minDistPoint=midPoints[mp];	
				}
			}
			
		}
		targDist[j] = (targetPos - (pos1+Vec2f(predictedOutput[0],predictedOutput[1]))).Length()/
						((targetPos-pos1).Length()+1);
		pos1+Vec2f(predictedOutput[0],predictedOutput[1]);
		inpt4NN.insertLast(Maths::Min(20.0,min_dist/10.0));
		inptNames.insertLast("Trj"+a);
	}

	/////////////////
	/////////////////
	inpt4NN.insertLast((isVisible(blob,target) ? 1.0 : 0.0 ));
	Vec2f currAim = (blob.getAimPos()-blob.getPosition());
	inpt4NN.insertLast(Maths::ATan2(currAim.x,-currAim.y));
	//inpt4NN.insertLast(blob.getVelocity().y);
	//inpt4NN.insertLast(blob.getVelocity().x);
	inptNames.insertLast("Vis");
	inptNames.insertLast("A");
	//inptNames.insertLast("MSPy");
	//inptNames.insertLast("MSPx");
	if (false and XORRandom(30)==3 and IDXFORPRINTS==argmax(goodArrows)){
			for (int i=0;i<inptNames.length;i++){
				print(inptNames[i]+(": "+inpt4NN[i]));
			}
		}
	return inpt4NN;
}
array<float> FeedForward(array<float>  inpt4NN, int idx)
{
	array<float> pred;
	NeuralNetwork@ nn;
	@nn = @Minds[idx];
	pred = nn.predict(inpt4NN);
	return pred;
}
array<float> FeedForward(int idx)
{
	array<float> pred;
	NeuralNetwork@ nn;
	@nn = @Minds[idx];
	array<float> static_inpr = array<float>(nn.Layer1[0].length-1,1);
	pred = nn.predict(static_inpr);
	//print("4");
	return pred;
}
string Array2String(array<Vec2f> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}
string Array2String(array<double> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}
string Array2String(array<float> arr)
{
	string s = "";
	int i=0;
	for (;i<arr.length();i++){
		s+=arr[i]+"; ";
	}
	return s;
}
float fit_score(CBlob@ this)
{
	float score=0;
	
	int na = NumArrows(this);
	score = (na<10 ? na : (10-(na-10) ));
	int kills = this.getPlayer().getKills();
	int assists = this.getPlayer().getAssists();
	score = score + (kills*100+assists*30)+(na+1);
	this.getPlayer().setScore(score);
	return score;
}
float maxim(array<float>arr)
{
	float MAX = -10000;
	for (int i=0;i<arr.length;i++)
	{
		if (arr[i]>MAX){
			MAX = arr[i];
		}
	}
	return MAX;
}
int argmax(array<float>arr)
{
	int argMaxIdx = -1;
	float m = maxim(arr);
	return arr.find(m);
}
int NumArrows(CBlob@ this)
{
	const string[] arrowTypeNames = { "mat_arrows",
                                  "mat_waterarrows",
                                  "mat_firearrows",
                                  "mat_bombarrows"
                                };
	ArcherInfo@ archer;
	if (!this.get("archerInfo", @archer))
	{
		return -1;
	}
	if (archer.arrow_type >= 0 && archer.arrow_type < arrowTypeNames.length)
	{
		return this.getBlobCount(arrowTypeNames[archer.arrow_type]);
	}
	return -1;
}
void onRender(CSprite@ this){
	int idx,team;
	if (this.getBlob().getPlayer() !is null){
		idx = myAtoi(this.getBlob().getPlayer().getUsername());
		team = this.getBlob().getPlayer().getTeamNum();
	}
	else
		return;
	int Color3rd = 120;
	
	float amount = 150.0;//3.0*this.getBlob().get_u32("fire time");
	Vec2f halfParab = (this.getBlob().getAimPos()-this.getBlob().getPosition());
	float tmp;
	//halfParab.x = 
	halfParab = Vec2f(amount*((halfParab.x)/halfParab.Length()),(amount*(halfParab.y)/halfParab.Length()));
	halfParab = this.getBlob().getPosition()+halfParab;
	//GUI::DrawLine(this.getBlob().getPosition(),halfParab, SColor(0,100*this.getBlob().getPlayer().getTeamNum(),0,255));
	
	//GUI::DrawLine(this.getBlob().getPosition(),targets[idx], SColor(Color3rd,0,Color3rd,255));
	Vec2f pos1 = this.getBlob().getPosition()+Vec2f(this.isFacingLeft() ? 2 : -2, -2);//+Vec2f(0.0,(team==0 ? -20.0 : 0.0));
	if (idx==argmax(goodArrows) and this.getBlob().getPlayer().isBot()){ //not  and false){// or ){
		float a;
		array<double> predictedOutput(4);
		array<Vec2f> midPoints(3);
		for (float j=0.0;j<=2.0;j+=1.0)
		{
			
			a = 17.59*(j==0.0 ? 1.0 :
					  (j==1.0 ? (1.0f / 3.0f) 
					  			: (4.0f / 5.0f))
						  );
			//REGRESSOR INPUT/OUTUPUT	
			Vec2f maxVel = (this.getBlob().getAimPos()-this.getBlob().getPosition());
			bool raySolid=false;
			float min_dist=1000.0;
			float currDist;
			Vec2f minDistPoint;
			maxVel = maxVel*(a/maxVel.Length());
			array<float> inpu ={0,0,maxVel.x,maxVel.y};
			for (int k=0;k<4;k++)
					predictedOutput[k]=inpu[k];
			int i=0;
			while(i<100 and !raySolid)
			{
				i+=1;
				inpu = enanchedInput(Vec2f(inpu[0],inpu[1]),
									Vec2f(inpu[2],inpu[3]));
				
				predictedOutput = predict(inpu[0],inpu[1],inpu[2],inpu[3],inpu[4],inpu[5],inpu[6],inpu[7]);
				//GUI::DrawLine(pos1+Vec2f(inpu[0],inpu[1]),
				//			pos1+Vec2f(predictedOutput[0],predictedOutput[1]),
				//			SColor(0,255,(i%2==0 ? 255 : 0),255));

				//print("inpu "+Array2String(inpu)+" output "+Array2String(predictedOutput));
				midPoints[0] = pos1+Vec2f(inpu[0],inpu[1]);
				for (int k=0;k<4;k++)
					inpu[k]=predictedOutput[k];
				if (j<-31.0){
					raySolid = getMap().rayCastSolid(pos1+Vec2f(inpu[0],inpu[1]),
							pos1+Vec2f(predictedOutput[0],predictedOutput[1]), Vec2f());
				}
				else{
					midPoints[2] = pos1+Vec2f(predictedOutput[0],predictedOutput[1]);
					midPoints[1] = midPoints[0]+(midPoints[2]-midPoints[0])/2.0;
					GUI::DrawLine(midPoints[0],midPoints[1],SColor(255,255,(i%2==0 ? 255 : 0),255));
					GUI::DrawLine(midPoints[1],midPoints[2],SColor(0,0,(i%2==0 ? 255 : 0),255));
					//print(midPoints[0]+" and "+midPoints[2]);
					
					raySolid = getMap().rayCastSolid(midPoints[0],midPoints[1], Vec2f())
								and getMap().rayCastSolid(midPoints[1],midPoints[2], Vec2f());
					for (int mp=0;mp<3;mp++){
					currDist = (targets[idx]-midPoints[0]).Length();
					if (currDist<min_dist){
							min_dist=currDist;
							minDistPoint=midPoints[mp];	
						}
					}
				}

			}
			if (j!=1.0)
				GUI::DrawLine(targets[idx],minDistPoint,SColor(255,255,255,255));
		}

		//OTHER INPUTS for self perception
		int nrays = 3;
		float nintyRad = PI/2;
		float angleStep = PI/(nrays)*(2.0/3.0);
		Vec2f target = targets[idx];
		
		float c=0;
		float customAngle = nintyRad+angleStep*c;
		Vec2f otherP;
		bool obstructed = false;
		float theta;
		Vec2f Vel = (this.getBlob().getAimPos()-this.getBlob().getPosition());
		theta = Maths::ATan2(Vel.x,-Vel.y)-(PI);
		for (int c=-nrays/2;c<nrays/2+1.0;c++)
		{
			customAngle = nintyRad+angleStep * (c)+theta;
			otherP.x = Maths::Cos(customAngle);
			otherP.y = Maths::Sin(customAngle);
			otherP = otherP*50.0;
			obstructed = getMap().rayCastSolid(pos1, pos1+otherP, Vec2f_zero);
			GUI::DrawLine(pos1,pos1+otherP,SColor(0,255,255,(obstructed ? 255 : 0)));
		}
		GUI::DrawArrow(pos1,target,SColor(255,255,0,0));
	}
}
void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	string name;
	this.set_u32("start charge time",0);
	if (player !is null)
		if (this.isBot() or player.isBot())
		{	
			flagDumped=0;
			
			int idx = myAtoi(player.getUsername());
			print("epoch:"+epochs+") SETTING PLAYER AI"+idx);
			NeuralNetwork@ nn;
			//string bm; getRules().get("BestMind",bm);
			//print("MIND "+idx+" Is there now? "+(getRules().get("Mind"+idx,@nn))+" BEst MIND IS "+bm);
			//getRules().get("Mind"+idx,@nn);
			//if (!(getRules().get("Mind"+idx,@nn))){
			//	getRules().set("Mind"+idx,@NeuralNetwork(12,8,2));
			//	print("MIND"+idx+"Is there now? "+(getRules().get("Mind"+idx,@nn)));
			//}
			if (Minds[idx]==null){
				
				print("Init new NN for "+idx);
				if (getBestMindName() == "BN"+idx)
					@Minds[idx] =@NeuralNetwork("BN"+idx);//@NeuralNetwork(14,8,2);// 
				else
				{
					@Minds[idx] = @NeuralNetwork(8,10,1,-0.5,0.5);
					Minds[idx].saveToFile("NN"+idx);

					//@Minds[idx] = @NeuralNetwork(getBestMindName());//
					
				}
			}
			else
				print("epoch>0");
			print("FF of "+idx+ " IS "+Array2String(FeedForward(idx)));
			targets[idx]=Vec2f_zero;
			if (idx==0){
				for (int i=0; i<goodArrows.length; i++)
					print("Curr Score for "+i+" is"+(goodArrows[i]));///(1.0+arrowsShot[idx]));
			}
		}
}
/*
f32 onPlayerTakeDamage(CRules@ this, CPlayer@ victim, CPlayer@ attacker, f32 DamageScale)
{
	if (attacker !is null && attacker !is victim){
		print("victim is"+victim.getUsername());
		print(attacker.getUsername()+" is the attacker");
	}
	return DamageScale;
}
f32 SimpleonHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	
	print(this.getName()+" is this and hitter blob is "+hitterBlob.getName());
	//getPlayer().getUsername() +" for "+damage);
	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	print(this.getName()+" is this and hit blob is "+hitBlob.getName());
}
*/
f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (hitterBlob.getName()=="arrow")
	{	
		//print(this.getPlayer().getUsername()+" is this and hitter blob is "+hitterBlob.getName());
		//print(this.getPosition()+" is position, "+velocity.Length()+" is the velocity "+ worldPoint+" is position ");
		if (hitterBlob.getDamageOwnerPlayer().isBot())
		{	
			int idx = myAtoi(hitterBlob.getDamageOwnerPlayer().getUsername());
			float arrowDistance = Maths::Max(2.0f,(hitterBlob.getPosition()-targets[idx]).Length());
			if (hitterBlob.getDamageOwnerPlayer().getBlob() !is null)
			{
				float targetDistance = (hitterBlob.getDamageOwnerPlayer().getBlob().getPosition()-targets[idx]).Length();
				float multiplier = ((targetDistance*targetDistance)/(arrowDistance));
				set_emote(hitterBlob.getDamageOwnerPlayer().getBlob(),"thumbsup");
				/*print("arrow distance is "+arrowDistance);
				print("target distance is "+targetDistance);
				print("arrow distance is "+multiplier);*/
				print("AI "+idx+"s arrow was worth "+multiplier);
				{
					goodArrows[idx]+=multiplier;
					if (this.hasTag("dead")){
						goodArrows[idx]+=(multiplier*multiplier);
					}
				}

			}
		}
	}
	return damage;
}
int epochs = 0;
int flagDumped = 0;
void onStateChange(CRules@ this, const u8 oldState)
{
	string LastMapName = "Maps/Talf.png";
	print("GAME IS RUNNING? "+this.isMatchRunning()+", map is Last Map "+(getMap().getMapName()==(LastMapName))+" Map is: -"+getMap().getMapName()+"-");
    if (this.isMatchRunning() && getMap().getMapName()==LastMapName)
    {
		if (flagDumped!=0) return;
		flagDumped=1;
		epochs++;
		if (epochs<=1) return;
		//print("Minds are "+Minds.length);
		//for(int i=0;i<Minds.length;i++){
		//	if (Minds[i] is null) continue;
		//	print("Mind is"+i);
		//	Minds[i].printLayers();
		//}
		print("DUMPING SCORES");
		
        CBlob@[] players;
		getBlobsByTag("player", @players);
		for (int i=0;i<players.length;i++){
			CPlayer@ player = players[i].getPlayer();
			if (player.isBot())
			{	
				int idx = myAtoi(player.getUsername());
				float gain = (goodArrows[idx]);///(1.0+arrowsShot[idx]);
				fitnessValues[idx] = gain;
				print("new gain for "+player.getUsername()+" is "+gain);
				{
					print(player.getUsername()+" has score "+fitnessValues[idx]);
					saveNNIfBestOrLoadBestWithNoise(idx,gain);
				}
				player.setKills(0);
				player.setAssists(0);
				player.setDeaths(0);
				arrowsShot[idx] = 0.0;
				goodArrows[idx] = 0.0;
				fitnessValues[idx]=0.0;

				//if (player.hasTag("dead")) continue;
			} 
		}
				
    }
}

array<float> AddNoiseToVec(array<float> arr,float divider)
{
	int i=0;
	for (;i<arr.length();i++){
		arr[i]+=((XORRandom(30000)-15000)*1.0)/divider;//100 for [-1.5,1.5]
	}
	return arr;
}


string getBestMindName(){
	ConfigFile cfg = ConfigFile();
	string cost_config_file = "NNScores.cfg";
	cfg.loadFile("../Cache/"+cost_config_file);
	return cfg.read_string("NameBest");

}
void saveNNIfBestOrLoadBestWithNoise(int my_idx,float my_score)
{
	
	ConfigFile cfg = ConfigFile();
	string cost_config_file = "NNScores.cfg";
	cfg.loadFile("../Cache/"+cost_config_file);
	float best_score = cfg.read_f32("BestScore");
	NeuralNetwork@ nn;
	@nn = Minds[my_idx];
	if (my_score>best_score)
	{
		print("Name was "+nn.MYname);
		nn.MYname="NN"+my_idx;
		print("SAVING SCORE "+my_score+" for "+nn.MYname);
		cfg.add_f32("BestScore",my_score);
		cfg.add_f32("Cycle",epochs);
		cfg.add_f32("arrowsShot",arrowsShot[my_idx]);
		cfg.add_f32("goodarrows",goodArrows[my_idx]);
		cfg.add_string("NameBest","BN"+my_idx);
		cfg.saveFile(cost_config_file);
		nn.saveToFile("BN"+my_idx);
		return;
	}
	else
	{
		@Minds[my_idx] = @NeuralNetwork(cfg.read_string("NameBest"));
		Minds[my_idx].AddNoiseToNetwork(-0.1,0.1);

	}
}

void onInit(CBrain@ this)
{
	InitBrain(this);
	getRules().set("BestMind",getBestMindName());
}

void onTick(CBrain@ this){
	bool guard = false; //this.getBlob().getPlayer().getTeamNum()==1;
	if (guard)
		onTickBASIC(this);
	else
		onTickVALE(this);
}
void onTickVALE(CBrain@ this)
{
	CBlob @oldTarget = this.getTarget();
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	this.getCurrentScript().tickFrequency = 29;
	int idx = myAtoi(blob.getPlayer().getUsername());
	
	// logic for target
	if (target !is oldTarget and target !is null){
		targets[idx]=target.getPosition();	
		Vec2f currAim = (blob.getAimPos()-blob.getPosition());
		currAim.x = Maths::Abs(currAim.x);
		currentAngle[idx] = (Maths::ATan2(Maths::Abs(currAim.x),currAim.y));
	}
	if (target !is null && this.getBlob().getPlayer() !is null && target.getPlayer() !is null)
	{
		targets[idx]=target.getPosition();
		
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotarrows = hasArrows(blob);
		if (!gotarrows)
		{
			strategy = Strategy::retreating;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		distance = (targets[idx]-blob.getPosition()).Length();
		const float difficulty = blob.getPlayer().getTeamNum();//blob.get_s32("difficulty");
		//bool vistTargGuard = (difficulty==0.0 ? !visibleTarget : true) ;
		if ((gotarrows) and (distance > 100.0f * (difficulty+1.0)))// and vistTargGuard)) * (difficulty+1.0))
		{				
				strategy = Strategy::chasing;
				if ((getGameTime()-blob.get_u32("start charge time"))/(ArcherParams::ready_time/2.0 + ArcherParams::shoot_period_2)>0.7)
					strategy = Strategy::attacking;
				//
		}
		else{
			if (!gotarrows) strategy = Strategy::retreating;
			else strategy = strategy = Strategy::attacking;
		}
		
		UpdateBlobVale(blob, target, strategy);
		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			strategy = Strategy::idle;
		}
		

		blob.set_u8("strategy", strategy);
	}
	FloatInWater(blob);
	 if (XORRandom(10)==0)
	 	switch (blob.get_u8("strategy"))
	 		{
	 			case Strategy::idle:
	 				set_emote( blob, "dots");
	 				break;
	 			case Strategy::retreating:
	 				set_emote(blob,"disappoint");
	 				break;
	 			case Strategy::attacking:
	 				set_emote(blob,"finger",1);
	 				break;
	 			case Strategy::chasing:
	 				if (blob.getTeamNum()==0)
	 					set_emote(blob,"mad");
	 				else
	 					set_emote(blob,"mad");
	 				break;
	 		}
	if (target==null){
		set_emote( blob, "question" );
	}

	3;
}

void UpdateBlobVale(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	//JustGo2(blob, target);
	JumpOverObstacles(blob);
	if (strategy == Strategy::chasing)
	{
		JustGo2(blob, target);
		//DefaultChaseBlob(blob, target);
	}
	else if (strategy == Strategy::retreating)
	{
		DefaultRetreatBlob(blob, target);
	}
	else if (strategy == Strategy::attacking)
	{
		3+3;
		
	}
	{

		array<float> AIPREDICTION;
		Vec2f targetVector = target.getPosition()-blob.getPosition();
		float targetAngle = Maths::ATan2(targetVector.y,targetVector.x);
		array<float> inpt4NN =  gatherInput(blob,target,idx);
		AIPREDICTION = FeedForward(inpt4NN,idx);
		
			
			
		u32 fTime = getGameTime()-blob.get_u32("start charge time");
		float AIout = 0.5;//AIPREDICTION[0];
		//////////////////////////
		//// hardcoded rules //////
		//////////////////////////
		float aaa1 = (ArcherParams::ready_time/2.0 + ArcherParams::shoot_period_2);
		float aaa2 = (ArcherParams::ready_time/2.0 + ArcherParams::shoot_period_1);
		float aaa3 = (ArcherParams::ready_time/3.0*ArcherParams::shoot_period);

		bool possoTirareMED =  ((-2.0+(fTime*1.0))/(ArcherParams::ready_time/2.0 + ArcherParams::shoot_period_2)>1.0);
		bool possoTirareMIN =  ((-2.0+(fTime*1.0))/(ArcherParams::ready_time/2.0 + ArcherParams::shoot_period_1)>1.0);
		bool possoTirareMAX =  ((-2.0+(fTime*1.0))/(ArcherParams::ready_time/3.0*ArcherParams::shoot_period)>1.0);
	
		bool TargetOnMAXTraj = (inpt4NN[3]<1.2);
		bool TargetOnMEDTraj = (inpt4NN[4]<1.2);
		bool TargetOnMINTraj = (inpt4NN[5]<1.2);
		float minDistanceFromTraj = Maths::Min(Maths::Min(inpt4NN[3],inpt4NN[4]),inpt4NN[5]);
		bool AIShotOut = true;
		bool r1 = ( (possoTirareMAX and TargetOnMAXTraj) ? true : false);
		bool r2 = ( (possoTirareMED and TargetOnMEDTraj) ? true : false);
		bool r3 = ( (possoTirareMIN and TargetOnMINTraj) ? true : false);
		bool r4 = (!(r2 or r3 or r1));
		float cosD = cosDist(blob.getAimPos()-blob.getPosition(),targetPos-blob.getPosition());
		if ((XORRandom(10)==4 or !r4) and idx == argmax(goodArrows)){

			print("\nInput IS"+Array2String(inpt4NN));
			print("Ff for "+idx+" is "+Array2String(AIPREDICTION));		
			print("cosDist is "+ cosD);

				
			print(currentAngle[idx]+" is lt "+inpt4NN[7]);
			//print("r2"+r2+" r1:"+r1+" r3:"+r3+" IS "+r4);
			//print("FIRE tIME" + (2.0+1.0*fTime)+"Min "+aaa2+" MED "+aaa1 + " MAX "+aaa3);
			//print("PossoTirareMin "+possoTirareMIN+ " MED"+possoTirareMED+" MAX "+possoTirareMAX);
		}
		//if (cosD>0.99){
		//	currentAngle[idx]= -PI/2.0-(3.0*PI)/2.0;// + Maths::ATan2(targetVector.x,targetVector.y);
		//	}
		
		bool IsVisibleAndTargets1and2areBigReceterAimToTarget = inpt4NN[6]>=0.5 and targetVector.Length()<100;
		AIShotOut = AIShotOut and r4;
		
		//AIout = (inpt4NN[3]<1.0)or (inpt4NN[5]<1.0)or (inpt4NN[4]<1.0) ? Maths::Min(inpt4NN[3],Maths::Min(inpt4NN[4],inpt4NN[5]))*0.1 : 1.0;
		//AIout = Maths::Cos(inpt4NN[7]+PI/2);// (inpt4NN[5]<2.0) ? 0.1 : 1.0;
		if ((
			TargetOnMAXTraj or
			TargetOnMEDTraj  or
			TargetOnMINTraj 
		) and false)
			AIout *=0.1;

		currentAngle[idx]+=(PI/180.0)*AIout;
		
		if (fTime>0 and !AIShotOut) {
			int idx = myAtoi(blob.getPlayer().getUsername());
			arrowsShot[idx]+=1.0;
			blob.set_u32("start charge time",getGameTime());
		}
		
		float DeltaX = targetVector.Length()*(Maths::Cos(currentAngle[idx]));
		float DeltaY = targetVector.Length()*(Maths::Sin(currentAngle[idx]));
		DeltaX = target.getPosition().x>blob.getPosition().x ? Maths::Abs(DeltaX) : -Maths::Abs(DeltaX);
		Vec2f targetPos = myPos+Vec2f(DeltaX,DeltaY);


		
		//blob.setAimPos(targetPos);
		if (IsVisibleAndTargets1and2areBigReceterAimToTarget)
			blob.setAimPos(target.getPosition());
			
		else
			blob.setAimPos(targetPos);
		//AIShotOut = true;
		blob.setKeyPressed(key_action1, AIShotOut);
	}
}


void onTickBASIC(CBrain@ this)
{
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// logic for target

	this.getCurrentScript().tickFrequency = 29;
	if (target !is null)
	{
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotarrows = hasArrows(blob);
		if (!gotarrows)
		{
			strategy = Strategy::idle;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		if (visibleTarget)
		{
			const s32 difficulty = 1;
			if ((!blob.isKeyPressed(key_action1) && getGameTime() % 300 < 240 && distance < 30.0f + 3.0f * difficulty) || !gotarrows)
				strategy = Strategy::retreating;
			else if (gotarrows)
			{
				strategy = Strategy::attacking;
			}
		}

		UpdateBlob(blob, target, strategy);

		// lose target if its killed (with random cooldown)

		if (LoseTarget(this, target))
		{
			strategy = Strategy::idle;
		}

		blob.set_u8("strategy", strategy);
	}
	else
	{
		RandomTurn(blob);
	}

	FloatInWater(blob);
}

void UpdateBlob(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	Vec2f targetPos = target.getPosition();
	Vec2f myPos = blob.getPosition();
	if (strategy == Strategy::chasing)
	{
		DefaultChaseBlob(blob, target);
	}
	else if (strategy == Strategy::retreating)
	{
		DefaultRetreatBlob(blob, target);
	}
	else if (strategy == Strategy::attacking)
	{
		AttackBlob(blob, target);
	}
}


void AttackBlob(CBlob@ blob, CBlob @target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - mypos;
	f32 targetDistance = targetVector.Length();
	const s32 difficulty = 1;

	JumpOverObstacles(blob);

	const u32 gametime = getGameTime();

	// fire

	if (targetDistance > 25.0f)
	{
		u32 fTime = blob.get_u32("fire time");  // first shot
		bool fireTime = gametime < fTime;

		if (!fireTime && (fTime == 0 || XORRandom(130 - 5.0f * difficulty) == 0))		// difficulty
		{
			const f32 vert_dist = Maths::Abs(targetPos.y - mypos.y);
			const u32 shootTime = Maths::Max(ArcherParams::ready_time, Maths::Min(uint(targetDistance * (0.3f * Maths::Max(130.0f, vert_dist) / 100.0f) + XORRandom(20)), ArcherParams::shoot_period));
			blob.set_u32("fire time", gametime + shootTime);
		}

		if (fireTime)
		{
			bool worthShooting;
			bool hardShot = targetDistance > 30.0f * 8.0f || target.getShape().vellen > 5.0f;
			f32 aimFactor = 0.45f - XORRandom(100) * 0.003f;
			aimFactor += (-0.2f + XORRandom(100) * 0.004f) / float(difficulty > 0 ? difficulty : 1.0f);
			blob.setAimPos(blob.getBrain().getShootAimPosition(targetPos, hardShot, worthShooting, aimFactor));
			if (worthShooting)
			{
				blob.setKeyPressed(key_action1, true);
			}
		}
	}
	else
	{
		blob.setAimPos(targetPos);
	}
}
