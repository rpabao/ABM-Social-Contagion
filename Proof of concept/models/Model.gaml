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

	//Dimension of the grid agent
	int nb_cols <- 50;
	int nb_rows <- 30;
	
	int action_drink <- 0 parameter:true among:[0,1,2,3,4,5];
	int action_close_interaction <- 0 parameter:true among:[0,1,2,3,4,5];
	
	int nbperson <- 15 parameter: true;
	float vision_amplitude <- 80.0 parameter: true min:1.0 max:80.0 step:1;
	bool showVision <- false parameter: true;
	float perceive_distance <- 5.0 parameter: true min:1.0 max:10.0 step:1;
	bool vision_masked_by_walls <- true;
	float prob_wander <- 0.5 parameter: true;
	
	float mean_speed <- 0.1 parameter: true;
	float std_speed <- 0.05 parameter: true;
	
	int threshold_tick_target_location <- 50;
	
	float mean_thresholdNorm <- 0.1;
	float std_thresholdNorm <- 0.1;
	
	float contagion_no_mask <- 0.03 parameter: true min:0.0 max:1.0 step:0.01;
	float contagion_no_distancing <- 0.06 parameter: true min:0.0 max:1.0 step:0.01;
	
	float distancing_value <- 0.1 parameter: true min:0.0 max:1.0 step:0.01;
	
	float prob_making_friends <- 0.1 parameter: true;
	
	int nbMask <- 0 update: person count each.is_wearing_mask;
	int nbDistancing <- 0 update: person count each.is_keeping_distance;
	
	list<cell> free_cells;
	list<cell> free_cells_base;
		
	predicate mask_protects <- new_predicate("mask_protects");
	predicate distancing_protects <- new_predicate("distancing_protects");
	
	predicate move <- new_predicate("move");
	
	predicate interact <- new_predicate("interact");
	predicate need_close_interaction <- new_predicate("need_close_interaction");
	
	predicate wearMask <- new_predicate("wearMask");
	predicate removeMask <- new_predicate("removeMask");
	
	predicate keep_distance <- new_predicate("keep_distance");
	predicate break_distance <- new_predicate("break_distance");
	
	predicate need_to_drink <- new_predicate("need_to_drink");
	predicate drink <- new_predicate("drink");
	
	predicate need_to_eat <- new_predicate("need_to_eat");
	predicate eat <- new_predicate("eat");
	
	predicate need_to_replace_mask <- new_predicate("need_to_replace_mask");
	predicate replace_mask <- new_predicate("replace_mask");
	
	predicate no_one_around <- new_predicate("no_one_around");
	predicate place_is_crowded <- new_predicate("place_is_crowded");
	
	predicate neighbor_no_mask <- new_predicate("neighbor_no_maskk");
	predicate neighbor_no_distancing <- new_predicate("neighbor_no_distancing");
	
	predicate sneeze <- new_predicate("sneeze");
	predicate neighbor_sneezed <- new_predicate("neighbor_sneezed");
	
	predicate copy_neighbor_no_mask <- new_predicate("copy_neighbor_no_mask");
	predicate copy_neighbor_no_distancing <- new_predicate("copy_neighbor_no_distancing");
	
	emotion fearInfected <- new_emotion("fear");
	
	geometry free_space;
	
	
	init{
		free_space <-copy(world.shape);
		
		create wall from: wall_shapefile {
			ask cell overlapping self {
				is_wall <- true;
			}
			free_space <- free_space - (shape  + 0.5);
		}
		
		free_space <- free_space.geometries first_with (each overlaps location);
		
		free_cells <- cell where (not each.is_wall);
		free_cells <- free_cells overlapping free_space;
		free_cells_base <- copy(free_cells);
		
		/*
		loop temp over: free_cells{
				ask temp{
					self.color <- #violet;
				}
			}	
		*/
		
		create person number: nbperson;
	}
	
	reflex action_drink when: action_drink>0{
		ask action_drink among person {
			do add_belief(predicate:need_to_drink, lifetime: 50);
		}
		action_drink <- 0;
	}
	
	reflex action_close_interaction when: action_close_interaction>0{
		ask action_close_interaction among person{
			do add_belief(predicate:need_close_interaction,lifetime: 50);
		}
		action_close_interaction <- 0;
	}
	
	reflex update_free_cells{
		free_cells <- copy(free_cells_base);
		ask person{
			free_cells <- free_cells - myCell;
			myCell.color <- rgb("white");
		}
		/*
		ask free_cells{
			color <- rgb(230,230,230);
		}	
		/*/		
	}
	
	reflex pause when: false{
		write "Simulation paused: " + average_duration;
		do pause;
	}
}

//Grid species to discretize space
grid cell width: nb_cols height: nb_rows neighbors: 8 {
	bool is_wall <- false;
	rgb color <- #white;	
}



//Species which represent the wall
species wall {
	aspect default {
		draw shape color: #black ;
	}
}



species person skills: [moving] control: /*parallel*/simple_bdi{
	cell target;
	cell myCell update: cell(location);
	rgb color <- #white;
	rgb border_color <- #black;
	geometry perceived_area;
	path myPath <- nil;
	
	//list<person> perceived_neighbors;
	
	bool is_wearing_mask <- true;
	bool is_keeping_distance <- true;
	bool is_copying_others_no_mask <- false;
	bool is_copying_others_no_distancing <- false;
	
	int tick_target_location;
	
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
	
		
	reflex walk when:target!=nil and not has_belief(need_to_drink){
		float actual_speed <- speed;
		
		if((self distance_to target) < (speed * step) or tick_target_location > threshold_tick_target_location){
			target<-nil;
		}
		else{
			if(is_keeping_distance){
				list<cell> my_free_cells <- copy(free_cells);
				ask person{
					if(self!=myself){
						my_free_cells <- my_free_cells - neighbors_at(self.myCell,distancing_value);
					}
				}
				myPath <- path_between(my_free_cells,myCell,target);
			}
			else {
				myPath <- path_between(free_cells,myCell,target);
			}
			if(myPath!=nil){
				do follow path: myPath speed: actual_speed;
				current_path <- nil;
				myPath <- nil;
			}
		}
		tick_target_location <- tick_target_location+1;
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
		cell temp_cell <- one_of(free_cells);
		location <- temp_cell.location;
		free_cells <- free_cells - temp_cell;
		
		// ADDING INITIAL BELIEFS AND DESIRES
		
		do add_belief(predicate:mask_protects);
		
		do add_belief(predicate:distancing_protects);
		
		do add_desire(predicate:move);
		
		
		do update_perceive_area;
		
	}
	
	
	perceive target: self parallel: true{
		if (is_wearing_mask and is_keeping_distance){ color <- #green;}
		else if (is_wearing_mask and not is_keeping_distance){ color <- #blue;}
		else if (not is_wearing_mask and is_keeping_distance){ color <- #red;}
		else if (not is_wearing_mask and not is_keeping_distance){ color <- #white;}
		
		if(not has_belief(neighbor_no_mask)){
			do remove_intention(copy_neighbor_no_mask, true);
			is_copying_others_no_mask <- false;
		}
		if(not has_belief(neighbor_no_distancing)){
			do remove_intention(copy_neighbor_no_distancing, true);
			is_copying_others_no_distancing <- false;
		}
		
		
		if(has_belief(need_to_drink)){
			color <- #yellow;
		}
		else{
			do remove_intention(drink, true);
		}
		
		if(not has_belief(need_to_eat)){
			do remove_intention(eat, true);
		}
		
		if(not has_belief(need_to_replace_mask)){
			do remove_intention(replace_mask, true);
		}
		
		if(has_belief(need_close_interaction)){
			color <- #orange;
		}
		else{
			do remove_intention(interact, true);
		}
		
		do update_perceive_area;
		
	}
	
	perceive target:cell in:perceived_area parallel: true{
	}
		
	perceive target:person in:perceived_area parallel: true{
		socialize when: flip(prob_making_friends);
		
		if(myself!=self and not self.is_wearing_mask){
			ask myself{
				do add_belief(predicate:neighbor_no_mask, lifetime:20);
			}
		}
		if(myself!=self and not self.is_keeping_distance){
			ask myself{
				do add_belief(predicate:neighbor_no_distancing, lifetime:20);
			}
		}
	}	
	
	perceive target:person in:1.0 parallel:true{
		if(myself!=self and myself.is_keeping_distance){
			myself.speed<-gauss(mean_speed,std_speed);
			myself.target <- one_of(free_cells_base);
			myself.tick_target_location <- 0;
		}
	}	
	
	
	
	rule belief:mask_protects new_desire:wearMask;
	rule belief:distancing_protects new_desire:keep_distance;
	
	rule belief:need_close_interaction new_desire:interact;
	
	rule belief:need_to_eat new_desire:eat;
	rule belief:need_to_drink new_desire:drink;
	rule belief:need_to_replace_mask new_desire:replace_mask;
	
	
	rule belief:neighbor_no_mask new_desire:copy_neighbor_no_mask when: flip(contagion_no_mask);
	rule belief:neighbor_no_distancing new_desire:copy_neighbor_no_distancing when: flip(contagion_no_distancing);
	
	
	
	plan move intention:move when: flip(prob_wander) and target=nil {
		speed<-gauss(mean_speed,std_speed);
		target <- one_of(free_cells_base);
		tick_target_location <- 0;
	}
	
	
	plan wearMask intention: wearMask when: not is_wearing_mask or not is_copying_others_no_mask{
		is_wearing_mask <- true;
		do remove_intention(wearMask, true);
	}
	
	plan removeMask intention:removeMask when: is_wearing_mask{
		is_wearing_mask <- false;
		do remove_intention(removeMask, true);
	}
	
	plan keep_distance intention: keep_distance when: not is_keeping_distance or not is_copying_others_no_distancing{
		is_keeping_distance <- true;
		do remove_intention(keep_distance, true);
	}
	
	plan break_distance intention:break_distance when: is_keeping_distance{
		is_keeping_distance <- false;
		do remove_intention(break_distance, true);
	}
	
	plan drink intention:drink{	
		do add_subintention(get_current_intention(),removeMask, true);
		do current_intention_on_hold();
	}
	
	plan interact intention:interact{	
		do add_subintention(get_current_intention(),break_distance, true);
		do current_intention_on_hold();
	}
	
	plan copy_neighbor_no_mask intention: copy_neighbor_no_mask{
		is_wearing_mask <- false;
		is_copying_others_no_mask <- true;
	}
	
	plan copy_neighbor_no_distancing intention: copy_neighbor_no_distancing{
		is_keeping_distance <- false;
		is_copying_others_no_distancing <- true;
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
		draw triangle(0.75) rotate: 90 + heading color: color border: border_color;
		if(is_copying_others_no_mask or is_copying_others_no_distancing){
			draw circle(1.0) color: #green empty:true border:#red ;
		}
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
			
			overlay position: { 0, 0 } size: { 280 #px, 140 #px } background: # black transparency: 0.5 border: #black rounded: true
            {
            	float y <- 30#px;
                draw triangle(20#px) at: { 20#px, 30#px } color:#green border:#black;
                draw "Mask & Distancing" at: { 40#px, 30#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                draw triangle(20#px) at: { 20#px, 55#px } color:#blue border:#black;
                draw "Mask & NO Distancing" at: { 40#px, 55#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                draw triangle(20#px) at: { 20#px, 80#px } color:#red border:#black;
                draw "NO Mask & Distancing" at: { 40#px, 80#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                draw triangle(20#px) at: { 20#px, 105#px } color:#white border:#black;
                draw "NO Mask & NO Distancing" at: { 40#px, 105#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                //draw triangle(20#px) at: { 20#px, 130#px } color:#yellow border:#black;
                //draw "Drinking water" at: { 40#px, 130#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                //draw triangle(20#px) at: { 20#px, 155#px } color:#yellow border:#black;
                //draw "Drinking water" at: { 40#px, 155#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                //draw triangle(20#px) at: { 20#px, 180#px } color:#orange border:#black;
                //draw "Close interaction" at: { 40#px, 180#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                //draw triangle(20#px) at: { 20#px, 205#px } color:#brown border:#black;
                //draw "follow others" at: { 40#px, 205#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
                
                //draw triangle(20#px) at: { 20#px, 230#px } color:#darkred border:#black;
                //draw "wander in smoke" at: { 40#px, 230#px + 4#px } color: # white font: font("SansSerif", 18, #bold);
            }
			
			grid cell lines: rgb("black",30);
			species wall refresh: false;
			species person;
			species person aspect: perception;
			
//			graphics "test" {
//				draw free_space color: rgb("pink");
//			}
		}
		
		display charts {
			chart "compliance" {
				data "nb mask" value: nbMask color: #green;
				data "nb distancing" value: nbDistancing color: #blue;
			}
		}
	}
}

experiment stationBatch type: batch repeat:12{
	reflex infos{
		write "nbMask " + nbMask;
	}
}



