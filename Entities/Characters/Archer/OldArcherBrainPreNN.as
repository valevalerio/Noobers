// Archer brain

#define SERVER_ONLY

#include "BrainCommon.as"
#include "ArcherCommon.as"
#include "/Entities/Common/Emotes/EmotesCommon.as"
#include "RidgeRegressorAS.as"
#include "NN.as"
array<NeuralNetwork@> Minds(20);
array<array<float>> allShotWeights(20);
array<array<float>> allAimWeights(20);

array<Vec2f> targets(20,Vec2f_zero);

array<float> fitnessValues(20,0);

array<float> currentAngle(20,0);
array<float> goodArrows(20,0);
array<float> arrowsShot(20,0);

float PI = 3.1415927;
float EulerNum = 2.7182818284;
float constGravity = 9.81;


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
array<float> static_inpr = array<float>(5,1);
array<float> FeedForward(int idx)
{
	array<float> pred;
	if (flagDumped==1) return pred;
	//print("FEED FORWARD STEP FOR AI"+idx+" IS "+Array2String(pred)+" Mind is a thing"+Minds[idx].MYname);
	//if (nn is null)
	//			return pred;
	print("1*******"+idx);
	
	print("2");
	print("MINDS IS NULL"+(@Minds[idx]==null));
	print("3"+Minds[idx].MYname);
	pred = Minds[idx].predict(static_inpr);
	print("4");
	return pred;
}
float getAIBoolShot(CBlob@ blob,CBlob@ target,Vec2f aimPos,array<float> dists)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	bool verbose = false;// (XORRandom(1000)<10) && (idx==argmax(fitnessValues));
	//printInt("my idx",idx);
	array<float> ShotWeights = allShotWeights[idx];
	//print("Shot weights");
	//print(Array2String(ShotWeights));
	float bias = ShotWeights[0];
	float x1 = (1.0*blob.get_u32("fire time"))/(1.0*ArcherParams::shoot_period);
	float x2 = (1.0*blob.get_u32("fire time"))/(2.0*ArcherParams::shoot_period);
	float x3 = (1.0*blob.get_u32("fire time"))/(3.0*ArcherParams::shoot_period);
	float x4 = NumArrows(blob)/30.0;
	float x5 = dists[1-1];
	float x6 = dists[2-1];
	float x7 = dists[3-1];
	Vec2f col;
	
	float x10;
	if (!getMap().rayCastSolid(blob.getPosition(), aimPos, col)) x10 = 1.0; else x10 = -1.0;
	//bias +linear combination of other features
	float output =  ShotWeights[1]*x1 +
					ShotWeights[2]*x2 +
					ShotWeights[3]*x3 +
					ShotWeights[4]*x4 +
					ShotWeights[5]*x10 +
					ShotWeights[6]*x5 +
					ShotWeights[7]*x6 +
					ShotWeights[8]*x7 +
					bias;
	//What is the sintax for Maths::Tanh? It does not found the matching signature!
	//return Maths::Tanh(output); 


	if (verbose)
	{			
				string name = blob.getPlayer().getUsername();
				array<float> inputLR = 
				   {bias,
				    ShotWeights[1]*x1,
					ShotWeights[2]*x2,
					ShotWeights[3]*x3,
					ShotWeights[4]*x4,
					ShotWeights[5]*x5
					};
				print(Array2String(inputLR));
				printFloat(name+" SHOT output ",output);
	}

	
	return Maths::Cos(output); 
}
float getAIAim(CBlob@ blob,CBlob@ target)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	bool verbose = (XORRandom(1000)<100);//(XORRandom(1000)<10) && (idx==argmax(fitnessValues));
	//printInt("my idx",idx);
	array<float> AimWeights = allAimWeights[idx];
	float bias = AimWeights[0];
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - blob.getPosition();
	float x9 = (isVisible(blob,target) ? 1.0 : 0.0 );
	float x10;
	if (targetPos.x<blob.getPosition().x) x10 = 1.0; else x10 = -1.0;
	////////////////////////
	//self perception INPUT//
	////////////////////////
		array<float> selfPerceptionObstruction(8);
		int nrays = 8;
		float nintyRad = PI/2;
		float angleStep = PI/(nrays)*(2.0/3.0);
		Vec2f pos1 = blob.getPosition()+Vec2f(blob.isFacingLeft() ? 2 : -2, -2);
		float c=0;
		float customAngle = nintyRad+angleStep*c;
		Vec2f otherP;
		bool obstructed = false;
		float theta;
		Vec2f Vel = (blob.getAimPos()-blob.getPosition());
		theta = Maths::ATan2(Vel.x,-Vel.y)-(PI);
		for (int c=-nrays/2;c<nrays/2;c++)
		{
			customAngle = nintyRad+angleStep * (c)+theta;
			otherP.x = Maths::Cos(customAngle);
			otherP.y = Maths::Sin(customAngle);
			otherP = otherP*50.0;
			obstructed = getMap().rayCastSolid(pos1, pos1+otherP, Vec2f_zero);
			selfPerceptionObstruction[c+(nrays/2)] = obstructed ? 1.0 : 0.0;
		}
		float x1 = selfPerceptionObstruction[0];
		float x2 = selfPerceptionObstruction[1];
		float x3 = selfPerceptionObstruction[2];
		float x4 = selfPerceptionObstruction[3];
		float x5 = selfPerceptionObstruction[4];
		float x6 = selfPerceptionObstruction[5];
		float x7 = selfPerceptionObstruction[6];
		float x8 = selfPerceptionObstruction[7];
	/////////////////
	/////////////////
	//Trajectories distancies //

		float a;
		array<float> targDist(3);
		array<double> predictedOutput(4);
		for (float j=0.0;j<=2.0;j+=1.0)
		{
			a = 17.59*(j==0.0 ? 1.0 :
							(j==1.0 ? (1.0f / 3.0f) : (4.0f / 5.0f))
						  );
			//REGRESSOR INPUT/OUTUPUT	
			Vec2f maxVel = (blob.getAimPos()-blob.getPosition());
			if (maxVel.Length()>0.0)
				maxVel = maxVel*(a/maxVel.Length());
			array<float> inpu ={0,0,maxVel.x,maxVel.y};
			for (int k=0;k<4;k++)
					predictedOutput[k]=inpu[k];
			int i=0;
			while(i<60 and !getMap().rayCastSolid(pos1+Vec2f(inpu[0],inpu[1]),
							pos1+Vec2f(predictedOutput[0],predictedOutput[1]), Vec2f()))
			{
				i+=1;
				inpu = enanchedInput(Vec2f(inpu[0],inpu[1]),
									Vec2f(inpu[2],inpu[3]));
				
				predictedOutput = predict(inpu[0],inpu[1],inpu[2],inpu[3],inpu[4],inpu[5],inpu[6],inpu[7]);
				
				//print("inpu "+Array2String(inpu)+" output "+Array2String(predictedOutput));
				for (int k=0;k<4;k++)
					inpu[k]=predictedOutput[k];

			}
			targDist[j] = (targetPos - (pos1+Vec2f(predictedOutput[0],predictedOutput[1]))).Length()/mapWidth;
		}

	/////////////////
	/////////////////
	//bias +linear combination of other features
	float output = 
	AimWeights[1]* x1 +
	AimWeights[2]* x2 +
	AimWeights[3]* x3 +
	AimWeights[4]* x4 +
	AimWeights[5]* x5 +
	AimWeights[6]* x6 +
	AimWeights[7]* x7 +
	AimWeights[8]* x8 +
	AimWeights[9]* x9 +
	AimWeights[10]*targDist[0] +
	AimWeights[11]*targDist[1] +
	AimWeights[12]*targDist[2] +
	//AimWeights[13]*x10 +
	bias;
	//What is the sintax for Maths::Tanh? It does not found the matching signature!
	//return Maths::Tanh(output);
	if (verbose and idx == 0)
	{			
				string name = blob.getPlayer().getUsername();
				//print("I'AM "+name+" my score is "+maxim(fitnessValues));
				//print("Enemy is at "+(x10>0.0 ? "Left" : "Right")+" x9=" + x9);
				array<float> inputLR = 
				   {
					   //x1,
					   //x2,
					   //x3,
					   //x4,
					   //x5,
					   //x6,
					   //x7,
					   //x8,
					   //x9,
					   targDist[0],
					   targDist[1],
					   targDist[2],
					   //x10
				   };
				//print(Array2String(inputLR));
				//printFloat(name+"output ",output);
	}



	float shotOut = getAIBoolShot(blob,target,targetPos,targDist);
	bool AIShotOut = shotOut>0;
	//printFloat("ShotBool",shotOut);
	//printBool("So ->",AIShotOut);
	u32 fTime = blob.get_u32("fire time");
	if (fTime>0 and !AIShotOut) {
		int idx = myAtoi(blob.getPlayer().getUsername());
		arrowsShot[idx]+=1.0;
	}
	if (AIShotOut)
	{
		blob.set_u32("fire time",fTime+1);
	}
	else
	{
		blob.set_u32("fire time", 0);	
	}
	//AIShotOut = true;
	blob.setKeyPressed(key_action1, AIShotOut);

	//////////////////////////////////////////
	return Maths::Cos(output); 
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
	score = score + (kills*100+assists*30)*(na+1);
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
	if (!this.getBlob().getPlayer().isBot() or idx==argmax(goodArrows)){
		float a;
		array<double> predictedOutput(4);
		for (float j=0.0;j<=2.0;j+=1.0)
		{
			a = 17.59*(j==0.0 ? 1.0 :
							(j==1.0 ? (1.0f / 3.0f) : (4.0f / 5.0f))
						  );
			//REGRESSOR INPUT/OUTUPUT	
			Vec2f maxVel = (this.getBlob().getAimPos()-this.getBlob().getPosition());
			Vec2f midP1,midP2;
			bool raySolid=false;
			maxVel = maxVel*(a/maxVel.Length());
			array<float> inpu ={0,0,maxVel.x,maxVel.y};
			for (int k=0;k<4;k++)
					predictedOutput[k]=inpu[k];
			int i=0;
			while(i<300 and !raySolid)
			{
				i+=1;
				inpu = enanchedInput(Vec2f(inpu[0],inpu[1]),
									Vec2f(inpu[2],inpu[3]));
				
				predictedOutput = predict(inpu[0],inpu[1],inpu[2],inpu[3],inpu[4],inpu[5],inpu[6],inpu[7]);
				//GUI::DrawLine(pos1+Vec2f(inpu[0],inpu[1]),
				//			pos1+Vec2f(predictedOutput[0],predictedOutput[1]),
				//			SColor(0,255,(i%2==0 ? 255 : 0),255));

				//print("inpu "+Array2String(inpu)+" output "+Array2String(predictedOutput));
				midP1 = pos1+Vec2f(inpu[0],inpu[1]);
				for (int k=0;k<4;k++)
					inpu[k]=predictedOutput[k];
				if (j<-31.0){
					raySolid = getMap().rayCastSolid(pos1+Vec2f(inpu[0],inpu[1]),
							pos1+Vec2f(predictedOutput[0],predictedOutput[1]), Vec2f());
				}
				else{
					midP2 = pos1+Vec2f(predictedOutput[0],predictedOutput[1]);
					Vec2f mp3 = midP1+(midP2-midP1)/2.0;
					GUI::DrawLine(midP1,mp3,SColor(255,255,(i%2==0 ? 255 : 0),255));
					GUI::DrawLine(mp3,midP2,SColor(0,0,(i%2==0 ? 255 : 0),255));
					//print(midP1+" and "+midP2);
					
					raySolid = getMap().rayCastSolid(midP1,mp3, Vec2f())
								and getMap().rayCastSolid(mp3,midP2, Vec2f());
				}

			}
			//GUI::DrawLine(pos1+Vec2f(predictedOutput[0],predictedOutput[1]),targets[idx],SColor(255,255,255,255));
		}

		//OTHER INPUTS for self perception
		int nrays = 10;
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
		for (int c=-nrays/2;c<nrays/2;c++)
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
float mapWidth=1;
void onSetPlayer(CBlob@ this, CPlayer@ player)
{
	flagDumped=0;
	mapWidth = (getMap().tilemapwidth*getMap().tilesize);
	string name;
	if (player !is null)
		if (this.isBot() or player.isBot())
		{	

			int idx = myAtoi(player.getUsername());
			print("epoch:"+epochs+") SETTING PLAYER AI"+idx);
			NeuralNetwork@ nn;
			if (Minds[idx]==null and epochs==0){
				print("Init new NN for "+idx);
				@Minds[idx] = @NeuralNetwork(getBestMindName());
				Minds[idx].AddNoiseToNetwork(-0.2,0.2);
			}
			else
				print("epoch>0");
			//FeedForward(idx);
			getBestWeightsWithNoise(idx);
			goodArrows[idx]=+idx;
			targets[idx]=Vec2f_zero;
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
				float multiplier = (targetDistance/(arrowDistance));
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
	string LastMapName = "Maps/Flat.png";
	print("GAME IS RUNNING? "+this.isMatchRunning()+", map is Last Map "+(getMap().getMapName()==(LastMapName))+" Map is: -"+getMap().getMapName()+"-");
    if (this.isMatchRunning() && getMap().getMapName()==LastMapName)
    {
		if (flagDumped!=0) return;
		flagDumped=1;
		print("DUMPING SCORES");
		print("Minds are "+Minds.length);
		epochs++;
        CBlob@[] players;
		getBlobsByTag("player", @players);
		for (int i=0;i<players.length;i++){
			CPlayer@ player = players[i].getPlayer();
			if (player.isBot())
			{	
				int idx = myAtoi(player.getUsername());
				float gain = (goodArrows[idx])/(1.0+arrowsShot[idx]);
				fitnessValues[idx] = gain;
				print("new gain for "+player.getUsername()+" is "+gain);
				{
					print(player.getUsername()+" has score "+fitnessValues[idx]);
					saveNNIfBestOrLoadBestWithNoise(idx,gain);
					//dumpLRWeightsIfBestOrLoadBestWithNoise(true,idx,gain);
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
void getBestWeights(int idx)
{	
	/*printInt("my Atoi",idx);
	*/
	print("Load Best Weights in AI"+idx);
	ConfigFile cfg = ConfigFile();
	string cost_config_file="../Cache/ArcherWeights.cfg";
	cfg.loadFile(cost_config_file);

	allShotWeights[idx].resize(0);
	cfg.readIntoArray_f32(allShotWeights[idx],"BestShotWeightsAI");
	//allShotWeights[idx] = AddNoiseToVec(allShotWeights[idx],100.0);

	allAimWeights[idx].resize(0);
	cfg.readIntoArray_f32(allAimWeights[idx],"BestAimWeightsAI");
	//allAimWeights[idx] = AddNoiseToVec(allAimWeights[idx],100.0);
	//printFloat("Shot Weights are",allShotWeights[idx].length());
	print(Array2String(allAimWeights[idx]));


}
void dumpLRWeightsIfBestOrLoadBestWithNoise(bool addNoise,int my_idx,float my_score)
{
	//printInt("my idx",idx);
	ConfigFile cfg = ConfigFile();
	string cost_config_file = "ArcherWeights.cfg";
	cfg.loadFile("../Cache/"+cost_config_file);
	float best_score = cfg.read_f32("BestScore");

	if (my_score>best_score)
		{
			cfg.add_f32("BestScore",my_score);
			cfg.add_string("AimWeights"+"AI"+my_idx,Array2String(allAimWeights[my_idx]));
			cfg.add_string("ShotWeights"+"AI"+my_idx,Array2String(allShotWeights[my_idx]));	
			cfg.add_string("BestAimWeights"+"AI",Array2String(allAimWeights[my_idx]));
			cfg.add_string("BestShotWeights"+"AI",Array2String(allShotWeights[my_idx]));	
			cfg.saveFile(cost_config_file);
		}
		
	else
	{
		getBestWeightsWithNoise(my_idx);
		cfg.add_string("AimWeights"+"AI"+my_idx,Array2String(allAimWeights[my_idx]));
		cfg.add_string("ShotWeights"+"AI"+my_idx,Array2String(allShotWeights[my_idx]));	
		cfg.saveFile(cost_config_file);
	}
	
	
	
}

void getBestWeightsWithNoise(int idx)
{	
	//printInt("my Atoi",idx);
	//print("Load Weights");
	ConfigFile cfg = ConfigFile();
	string cost_config_file="../Cache/ArcherWeights.cfg";
	cfg.loadFile(cost_config_file);

	allShotWeights[idx].resize(0);
	cfg.readIntoArray_f32(allShotWeights[idx],"BestShotWeightsAI");
	allShotWeights[idx] = AddNoiseToVec(allShotWeights[idx],100000.0);

	allAimWeights[idx].resize(0);
	cfg.readIntoArray_f32(allAimWeights[idx],"BestAimWeightsAI");
	allAimWeights[idx] = AddNoiseToVec(allAimWeights[idx],100000.0);
	/*AimWeights.resize(0);
	cfg.readIntoArray_f32(AimWeights,"AimWeights"+name);
	AimWeights = AddNoiseToVec(AimWeights,100.0);*/

	//printFloat("Shot Weights are",allShotWeights[idx].length());
	//print(Array2String(allShotWeights[idx]));
	//printFloat("Aim Weights are",AimWeights.length());

}
void getLRWeights(int srcIdx, string name)
{	
	int idx = myAtoi(name);
	//printInt("my Atoi",idx);
	//print("Load Weights");
	ConfigFile cfg = ConfigFile();
	string cost_config_file="../Cache/ArcherWeights.cfg";
	cfg.loadFile(cost_config_file);

	allShotWeights[idx].resize(0);
	cfg.readIntoArray_f32(allShotWeights[idx],"ShotWeightsAI"+srcIdx);

	allAimWeights[idx].resize(0);
	cfg.readIntoArray_f32(allAimWeights[idx],"AimWeightsAI"+srcIdx);
	/*AimWeights.resize(0);
	cfg.readIntoArray_f32(AimWeights,"AimWeights"+name);
	AimWeights = AddNoiseToVec(AimWeights,100.0);*/

	//printFloat("Shot Weights are",allShotWeights[idx].length());
	//print(Array2String(allShotWeights[idx]));
	//printFloat("Aim Weights are",AimWeights.length());

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
	if (my_score>best_score)
	{
		print("Name was "+Minds[my_idx].MYname);
		Minds[my_idx].MYname="NN"+my_idx;
		print("SAVING SCORE as "+Minds[my_idx].MYname);
		cfg.add_f32("BestScore",my_score);
		cfg.add_string("NameBest","NN"+my_idx);
		cfg.saveFile(cost_config_file);
		Minds[my_idx].saveToFile("NN"+my_idx);
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
	print("Minds are "+Minds.length);
	//Minds.insertLast(@NeuralNetwork(getBestMindName()));
	print("SCORES:"+Array2String(goodArrows));
	
}

void onTick(CBrain@ this)
{
	SearchTarget(this, false, true);

	CBlob @blob = this.getBlob();
	CBlob @target = this.getTarget();

	// logic for target

	this.getCurrentScript().tickFrequency = 29;
	int idx = myAtoi(blob.getPlayer().getUsername());
	if (target !is null && this.getBlob().getPlayer() !is null && target.getPlayer() !is null)
	{
		/*
		if (XORRandom(50)<5){
			print(blob.getPlayer().getUsername()+" is targeting "+ targets[idx]);
		}
		*/
		targets[myAtoi(blob.getPlayer().getUsername())]=target.getPosition();
		
		this.getCurrentScript().tickFrequency = 1;

		u8 strategy = blob.get_u8("strategy");
		const bool gotarrows = hasArrows(blob);
		if (!gotarrows)
		{
			strategy = Strategy::retreating;
		}

		f32 distance;
		const bool visibleTarget = isVisible(blob, target, distance);
		const float difficulty = blob.getPlayer().getTeamNum()*15.0;//blob.get_s32("difficulty");
		if ((gotarrows) and (distance > 100.0f * (difficulty+1.0)))
		{				
				strategy = Strategy::chasing;
				//
		}
		else{
			if (!gotarrows) strategy = Strategy::retreating;
			else strategy = strategy = Strategy::attacking;
		}
		
		UpdateBlob(blob, target, strategy);

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
					set_emote( blob, Emotes::dots);
					break;
				case Strategy::retreating:
					set_emote(blob,Emotes::disappoint);
					break;
				case Strategy::attacking:
					set_emote(blob,Emotes::finger);
					break;
				case Strategy::chasing:
					if (blob.getTeamNum()==0)
						set_emote(blob,Emotes::right);
					else
						set_emote(blob,Emotes::left);
					break;
			}
	if (target==null){
		set_emote( blob, Emotes::question );
	}
}

void UpdateBlob(CBlob@ blob, CBlob@ target, const u8 strategy)
{
	int idx = myAtoi(blob.getPlayer().getUsername());
	if (XORRandom(3)==0){
		targets[idx]=target.getPosition();
		//print("AI"+idx+" has as target"+target.getPlayer().getUsername());
	}

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
		3+3;
		//if (idx%2==0)
		//	AttackBlob(blob, target);
	}


	//if (idx%2!=0)
	{
		Vec2f aimPos = AIAiming(blob,target);
	}
}


Vec2f AIAiming(CBlob@ blob, CBlob @target)
{

		int idx = myAtoi(blob.getPlayer().getUsername());
		Vec2f mypos = blob.getPosition();
		float AIout = getAIAim(blob,target);
		//AIout*=180.0; //[-180,180]
		
		
		Vec2f targetVector = target.getPosition()-blob.getPosition();
		float x10 = 1.0;
		if ( target.getPosition().x<blob.getPosition().x) x10 = 1.0; else x10 = -1.0;
		currentAngle[idx]+=(PI/180.0)*AIout;
		//FeedForward(idx);
		
		float DeltaX = targetVector.Length()*Maths::Cos(currentAngle[idx]);
		float DeltaY = targetVector.Length()*Maths::Sin(currentAngle[idx]);
		DeltaX = target.getPosition().x>blob.getPosition().x ? Maths::Abs(DeltaX) : -Maths::Abs(DeltaX);
		
		//DeltaY = target.getPosition().y>=blob.getPosition().y ? Maths::Abs(DeltaY) : DeltaY;
		/*
		if (target.getPosition().x>blob.getPosition().x){
			print("my target is at right");
			print("mypos is "+blob.getPosition().x+" DeltaX should be positive and is "+DeltaX);
		}
		printFloat("Deltas",DeltaY);
		printFloat("      ",DeltaX);
		
		printFloat("         ",targetVector.y);*/
		Vec2f targetPos = mypos+Vec2f(DeltaX,DeltaY);//targetVector*targetVector.Length();//Vec2f(DeltaX,DeltaY);
		/*if (myAtoi(blob.getPlayer().getUsername()) % 2 == 0){
			bool worthShooting;
			bool hardShot = targetVector.Length() > 240.0f;
			f32 aimFactor = 1.0f;
			blob.setAimPos(blob.getBrain().getShootAimPosition(targetPos, hardShot, worthShooting, aimFactor));
		}*/
		//if (isVisible(blob,target)) print("difference from target pos is "+(target.getPosition()-targetPos).Length());
		blob.setAimPos(targetPos);
		return targetPos;
		
}


void AttackBlob(CBlob@ blob, CBlob @target)
{
	Vec2f mypos = blob.getPosition();
	Vec2f targetPos = target.getPosition();
	Vec2f targetVector = targetPos - mypos;
	f32 targetDistance = targetVector.Length();
	const s32 difficulty = 15.0;

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
			f32 aimFactor = 0.45f;
			aimFactor += (-0.2f) / float(difficulty > 0 ? difficulty : 1.0f);
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

