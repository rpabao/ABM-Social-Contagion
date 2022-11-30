/*
 * 
 */
 
model Model

global{
	//Shapefile of the walls
	file wall_shapefile <- shape_file("../includes/Wall.shp");
	//Shapefile of the exit
	file exit_shapefile <- shape_file("../includes/Exit.shp");
	
	file bar_shapefile <- shape_file("../includes/Bar.shp");
	
	geometry shape <- envelope(wall_shapefile);

	//DImension of the grid agent
	int nb_cols <- 120;
	int nb_rows <- 80;
	
	
	int nbperson <- 15 parameter: true;
	float vision_amplitude <- 80.0 max: 180.0 parameter: true;
	bool showVision <- false parameter: true;
	bool vision_masked_by_walls <- true;
	float prob_wander <- 0.5 parameter: true;
	
	bool use_congestion <- false;
	float coeff_congestion <- 100.0;
	float dist_congestion <-1.0;
	
	float mean_speed <- 0.2 parameter: true;
	float std_speed <- 0.1 parameter: true;
	
	float mean_thresholdNorm <- 0.1;
	float std_thresholdNorm <- 0.1;
	
	float contagion_parameter <- 0.1 parameter: true;
	
	float propFriend <- 0.5;
	float thresholdFriend <- 0.25;
	
	//perception distance
	float normal_distance <- 4.0;
	
	int nbMask <- 0;
	int nbDistancing <- 0;
	
	list<cell> free_cells;
		
	predicate mask_protects <- new_predicate("mask_protects");
	predicate distancing_protects <- new_predicate("distancing_protects");
	
	predicate moving <- new_predicate("moving");
	
	predicate interact <- new_predicate("interact");
	predicate need_close_interaction <- new_predicate("need_close_interaction");
	
	predicate wearMask <- new_predicate("wearMask");
	predicate removeMask <- new_predicate("removeMask");
	
	predicate keep_distance <- new_predicate("keep_distance");
	
	predicate need_to_drink <- new_predicate("need_to_drink");
	predicate drinking <- new_predicate("drinking");
	
	predicate need_to_eat <- new_predicate("need_to_eat");
	predicate eating <- new_predicate("eating");
	
	predicate need_to_replace_mask <- new_predicate("need_to_replace_mask");
	predicate replacing_mask <- new_predicate("replacing_mask");
	
	predicate no_one_around <- new_predicate("no_one_around");
	predicate place_is_crowded <- new_predicate("place_is_crowded");
	
	predicate neighbor_no_mask <- new_predicate("neighbor_no_maskk");
	predicate neighbor_no_distancing <- new_predicate("neighbor_no_distancing");
	
	predicate neighbor_sneezed <- new_predicate("neighbor_sneezed");
	
	predicate copy_neighbor <- new_predicate("copy_neighbor");
	
	emotion fearInfected <- new_emotion("fear");
	
	geometry free_space;
	
	
	init{
		free_space <-copy(world.shape);
		//Creation of the wall and initialization of the cell is_wall attribute
		create furniture from: bar_shapefile {
			ask cell overlapping self {
				is_wall <- true;
			}
		}
	
		create wall from: wall_shapefile {
			ask cell overlapping self {
				is_wall <- true;
			}
			free_space <- free_space - (shape  + 0.1);
		}
		free_space <- free_space.geometries first_with (each overlaps location);
		//free_cells <- cell where (not each.is_wall or each.is_exit);
		
		//Creation of the exit and initialization of the cell is_exit attribute
		create exitt from: exit_shapefile {
			ask (cell overlapping self) where not each.is_wall{
				is_exit <- true;				
			}			
		}
		free_cells <- cell where ((not each.is_wall) or each.is_exit);
		free_cells <- free_cells overlapping free_space;
		ask cell {
			free_neighbors <- neighbors where not each.is_wall;
		}		
		
		//loop temp over: free_cells{
				//ask temp{
					//self.color <- #violet;
				//}
			//}
		
		
		create person number: nbperson;
		
	}
	
	reflex stop when: length(person)=0{
		write "time : " + average_duration;
		do pause;
//		do halt;
	}
}

//Grid species to discretize space
grid cell width: nb_cols height: nb_rows neighbors: 8 {
	bool is_wall <- false;
	bool is_exit <- false;
	//bool is_furniture <- false;
	list<cell> free_neighbors;
	rgb color <- #white;	
	
}

//Species exit which represent the exit
species exitt {
	bool is_active;
	init{
		if((self.name="exitt0") or (self.name="exitt1") or (self.name="exitt3")){
			is_active<-true;
		} else {
			is_active<-false;
		}
	}
	
	aspect default {
		draw shape color: #blue;
	}
}

//Species which represent the wall
species wall {
	aspect default {
		draw shape color: #black ;
	}
}

species furniture {
	aspect default {
		draw shape color: #yellow ;
	}
}


species person skills: [moving] control: /*parallel*/simple_bdi{
	point target;
	rgb color <- #white;
	geometry perceived_area;
	cell myCell update: cell(location);
	path myPath;
	
	bool wearingMask <- false;
	
	float perceive_distance <- 4.0;
	int tick;
	int tick1;
	
	bool use_emotions_architecture <- true;
	bool use_social_architecture <- true;
	bool use_personality <- true;
	bool use_norms <- true;
	
	// OCEAN model
	float openness <- gauss(0.5,0.12);
	float conscientiousness <- gauss(0.5,0.12); 
	float extroversion <- gauss(0.5,0.12);
	float agreeableness <- gauss(0.5,0.12);
	float neurotism <- gauss(0.5,0.12);
	
	person friend <-nil;
	person perceivedOther <- nil;
	bool hasFriend <- false;
	
	//float solidarity<-0.0;
	float thresholdLaw <- 1.0; 
	float thresholdNorm <- gauss(mean_thresholdNorm,std_thresholdNorm);
		
	action walk{
		float actual_speed <- speed;
		if (use_congestion) {
			int victims_around <- length(person at_distance dist_congestion);
			actual_speed <- max([0.1,speed * (1 - victims_around/coeff_congestion)]);	
		}
		if(myPath!=nil){
			do follow path: myPath speed: actual_speed;
		} else{
			do goto target:target on:world.shape;
		}
		if(cell(location).is_exit){
			do die;
		}
	}
	
	action update_path(point new_target) {
		if (target = nil) or (target != new_target) or (myPath = nil) or (myPath.target != new_target){
			target <- new_target;
			myPath <- free_cells path_between (self.location, target);
		}
	}
	
	action update_perceive_area {
		if (vision_amplitude < 180.0) {
			geometry vision_cone <-cone(heading-vision_amplitude,heading+vision_amplitude);
			perceived_area <- vision_cone intersection circle(perceive_distance); 
		} else {
			perceived_area <- circle(perceive_distance);
		}
		if (vision_masked_by_walls) {
			perceived_area <- perceived_area masked_by (wall,20);
		}
	}
	
	
	init{
		location <- one_of(free_cells).location;
		
		// ADDING INITIAL BELIEFS AND DESIRES
		
		//int lt_mask_protects <- max([10,round(gauss(50,15))]);
		do add_belief(predicate:mask_protects);
		
		//int lt_distancing_protects <- max([10,round(gauss(50,15))]);
		do add_belief(predicate:distancing_protects);
		
		do add_desire(predicate:moving, strength:1.0);
		
		
		do update_perceive_area;
		
		
		if(!hasFriend and flip(propFriend)){
			friend <- one_of(person where ((!each.hasFriend)and(each distance_to self <50)));
			if(!(friend=nil)){
				hasFriend<-true;
				do add_social_link(new_social_link(friend,gauss(0.5,0.12),gauss(0.0,0.33),gauss(0.5,0.12),gauss(0.5,0.12)));
				//solidarity <- get_solidarity(get_social_link(new_social_link(friend)));
				ask friend{
					friend <- myself;
					hasFriend<-true;
					do add_social_link(new_social_link(friend,gauss(0.5,0.12),gauss(0.0,0.33),gauss(0.5,0.12),gauss(0.5,0.12)));
					//solidarity <- get_solidarity(get_social_link(new_social_link(friend)));
				}
			}
		}
		
	}
	
	
	perceive target: self parallel: true{
		if (wearingMask){ 
			color <- #green;
		}
		
		if(flip(0.003)){
			focus id:"need_to_drink";
			tick <- 0;
		}
		
		do update_perceive_area;
		
		
	}
	
	perceive target:cell  in:perceived_area parallel: true{
		//if(smoke_level>50){
			//focus id:"smoke";
			//if(myself.perceive_distance=normal_distance){
				//if(myself.smokeQuantity<100){myself.smokeQuantity <- myself.smokeQuantity+5;}
			//}
		//}
	}
		
	perceive target:person in:perceived_area{
		//if(has_belief(fireSaw) and not myself.has_belief(fireSaw)){
			//focus id:"fire" strength: uncertaintyConversion is_uncertain:true;
			//ask myself{
				//do add_uncertainty(predicate:fireSaw,strength: uncertaintyConversion);
			//}
		//}
		if(myself!=self and not wearingMask and flip(contagion_parameter)){
			ask myself{
				do add_belief(neighbor_no_mask);
				tick1 <- 0;
			}
		}
	}		
	
	//perceive target:person in:perceived_area parallel:false{
		//emotional_contagion emotion_detected:fearInfected threshold:contagionThreshold;
		//socialize trust:gauss(0.0,0.33);
		//myself.perceivedOther<-self;
		//enforcement norm: "followOthers" sanction: "trustSanction" reward: "trustReward";
	//}
	
	//sanction trustSanction{
		//do change_trust(perceivedOther,-0.1);
	//}
	
	//sanction trustReward{
		//do change_trust(perceivedOther,0.1);
	//}
	
	
	perceive target:friend in:circle(5.0){
		//if(needHelp and self!=myself){
			//focus id:"helpFriend" lifetime:30;	
		//}
	}
	
	
	
	rule belief:mask_protects new_desire:wearMask;
	rule belief:distancing_protects new_desire:keep_distance;
	
	rule belief:need_to_drink new_desire:drinking;
	
	rule belief:neighbor_no_mask new_desire:copy_neighbor;
	
	plan move intention:moving when: flip(prob_wander){
		speed<-gauss(mean_speed,std_speed);
		if(target=nil){
			target <- one_of(free_cells).location;
			myPath <- free_cells path_between(location, target);	
		}
		do walk;
		
		if(self distance_to target < (speed * step)){
			target<-nil;
		}
	}
	
	
	plan wearMask intention: wearMask {
		wearingMask <- true;
		do remove_intention(wearMask, true);
	}
	
	plan drink intention:drinking{
		wearingMask <- false;
		color <- #yellow;
		tick <- tick+1;
		if(tick>5){
			do remove_intention(drinking, true);
			do remove_belief(need_to_drink);
		}
	}
	
	plan copy_neighbor intention: copy_neighbor{
		wearingMask <- false;
		color <- #red;
		tick1 <- tick1+1;
		if(tick1>1){
			do remove_belief(neighbor_no_mask);
			do remove_intention(copy_neighbor,true);
		}
	}

	
	/* 
	norm followSigns obligation: fleeing when: not has_belief(exitDoor)  finished_when: has_belief(exitDoor) {
		color <- #blue;
		speed<-1.0;
		do update_path(myBathroom.location);
		do walk;
	}
	
	norm followOthers intention: fleeing when:not has_belief(fireSaw) and (smokeQuantity > min_smoke) and (smokeQuantity < max_smoke) and not has_belief(directionExitDoor) finished_when: has_belief(exitDoor) or (smokeQuantity > max_smoke) or (smokeQuantity < min_smoke) threshold:thresholdNorm{
		color <- #brown;
		person follower <- nil;
		float maxTrust <- 0.0;
		float tempTrust <- -1.0;
		loop tempFollower over: victim where (each distance_to self <perceive_distance){
			tempTrust <- -1.0;
			if(has_social_link(new_social_link(tempFollower))){
				tempTrust <- get_trust(get_social_link(new_social_link(tempFollower)));
			}
			if (tempTrust > maxTrust){
				maxTrust <- tempTrust;
				follower <- tempFollower;
			}
		}
		if(follower != nil){
			target <- follower.target;
			do walk;
		} else {
			cell next_cell <- shuffle(free_cells where (each distance_to self <10.0)) with_min_of (each.smoke_level);
			do update_path(next_cell.location);		
			
			do walk;
			
			if(location = target){
				target<-nil;
			}
		}
	}
	
	plan avoidSmoke intention:fleeing priority: smokeQuantity /5.0 when: not has_belief(exitDoor) and (smokeQuantity > min_smoke) and (smokeQuantity < max_smoke) finished_when: has_belief(exitDoor) or (smokeQuantity > max_smoke) or (smokeQuantity < min_smoke){
		color <- #red;
		speed<-1.5;
		cell next_cell <- shuffle(free_cells where (each distance_to self <10.0)) with_min_of (each.smoke_level);
		do update_path(next_cell.location);		
		
		do walk;
		
		if(location = target){
			target<-nil;
		}
	}
	*/
	
	
	aspect default {
		draw triangle(0.75) rotate: 90 + heading color: color border: #black;
	}
	aspect perception {
		if (perceived_area != nil and showVision) {
			draw perceived_area color: #green empty:true border:#red ;
		}
	}
}

experiment Model type:gui{
	output{
		display map /*type: opengl*/{
			
			/*overlay position: { 0, 0 } size: { 230 #px, 260 #px } background: # black transparency: 0.5 border: #black rounded: true
            {
            	float y <- 30#px;
                draw triangle(10#px) at: { 20#px, 30#px } color:#white border:#black;
                draw "dance" at: { 40#px, 30#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 55#px } color:#green border:#black;
                draw "to the exit" at: { 40#px, 55#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 80#px } color:#yellow border:#black;
                draw "to the exit direction" at: { 40#px, 80#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 105#px } color:#purple border:#black;
                draw "through the smoke" at: { 40#px, 105#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 130#px } color:#red border:#black;
                draw "avoid smoke" at: { 40#px, 130#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 155#px } color:#orange border:#black;
                draw "help a friend" at: { 40#px, 155#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 180#px } color:#blue border:#black;
                draw "follow sign" at: { 40#px, 180#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 205#px } color:#brown border:#black;
                draw "follow others" at: { 40#px, 205#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                draw triangle(10#px) at: { 20#px, 230#px } color:#darkred border:#black;
                draw "wander in smoke" at: { 40#px, 230#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
            }*/
			
			grid cell lines: rgb("black",30);
			species wall refresh: false;
			species exitt refresh: false;
			species furniture aspect:default;
			species person;
			species person aspect: perception;
			
//			graphics "test" {
//				draw free_space color: rgb("pink");
//			}
		}
		
		//display charts {
			//chart "compliance" {
				//data "nb mask" value: nbMask color: #green;
				//data "nb distancing" value: nbDistancing color: #red;
			//}
		//}
	}
}

experiment stationBatch type: batch repeat:12{
	reflex infos{
		write "nbMask " + nbMask;
	}
}



