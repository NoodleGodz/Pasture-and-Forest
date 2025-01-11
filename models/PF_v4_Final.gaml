/**
 * Name: PFv4
 * Based on the internal empty template.
 * Author: Minh
 *
 * Description:
 * PFv4 is the final version of the PF simulation model, designed to study the interaction 
 * between herds and forest ecosystems. It builds upon previous versions by introducing 
 * the concept of a Forest Department regulation that determines the institutional 
 * authorized minimum size for grazing, as well as the calculation of herd behavior 
 * based on memory and respect for protected areas. This verision include every above verison before that.
 * This is the final version.
 * 
 * New Key Features:
 * - For each season calculates an institutional authorized minimum size by 
 * averaging the self-authorized minimum sizes reported by all shepherds, 
 * which determines which grove "is_protected" for the next grazing season.
 * - Add an atribute "respectful" (probability based on parameter) that :
 *   - respectful = avoid protected grove and forest smaller than self-authorized minimum sizes.
 *   - disrespectful = just avoid forest smaller than self-authorized minimum sizes (PF_v3 behavior).
 * - Added more detailed tracking of forest density and sustainability metrics,
 * as well as logging features for batch processing.
 * - Update vocabulary, change forest into grove for easier to understand.
 * 
 * What if all shepherds were to follow the Forest Department's regulations ?
 * 
 */


model PFv4

global
{
	int grid_size <- 50; 
	bool is_batch <- false;
	
	// Whether to shepherds to have any regulation or not
	// True mean Its is follow it minimum size (PFv3)
	// False mean Its free to eat anything (PFv2)
	bool is_ruled <- true;
	
	bool logged<-true;
	
	float forest_cover <- 0.3;
	int nb_herds <- 25;
	int end_season <- 50;
	float perception_range <- 4.5#m;
	float min_spread <- 0.0025;
	float max_spread <- 0.02;
	
	float regen_rate <- 0.03;
	float eating_cap <- 0.14;
	
	int cycle_per_month <- 10;
	int month_per_season <- 10;
	int months <- 1 update: 1+ cycle div cycle_per_month;
	int seasons <- 1 update: cycle div (cycle_per_month*month_per_season);
	bool change_month <- false update: (cycle mod cycle_per_month = 0) and cycle!=0 ;
	bool change_season <- false update: (cycle mod (cycle_per_month*month_per_season) = 0) and cycle!=0 ;
	// Forest percentage and total biomass
	float forestPercentage -> (length(land where each.grove)) / length(land);
	float totalBiomass -> sum(land where each.grove collect each.density);
	
	// Probability of a herd being respectful
	float prob_respectful <- 0.0;
	
	
	list<float> institutional_list <- [];
	float institutional_authorized_minimum_size <- 0.0;
	image_file goat0_image_file <- image_file("../includes/icons/goat.png");
	
	string save_file ; 
	
	init{
		do create_land;
		create herds number: nb_herds;
		if is_batch and self.name='Simulation 0'
		{// If batch mode, save results to a file
			write ("Save file at: "+ save_file);
   			save ["Simulation name","Respectful Rate","Deforestation Status","Last Seasons","Percentage of Groves","Total Biomasses","Sustainability"] to: save_file header:false;
		}
		
	}
	
	action create_land{
		int nb_tree <-  int(grid_size*grid_size*forest_cover);
		ask (nb_tree among land){
			self.grove <- true;
			density <- rnd(0.2, 1.0);
		}
		
	}
	reflex eat_clean when : length(land where each.grove)=0 and !is_batch{
			write('Total deforestation in '+ " Season: " + (seasons)+ " Month: " + (months) );
			write("This is not sustainable.");
			do pause;
	}
	
	reflex survive when: seasons > end_season and !is_batch {

	
	    write("Passed " + end_season + " Seasons with:");
	    write("Forest percentage: " + forestPercentage);
	    write("Biomasses: " + totalBiomass);
	
	    if (forestPercentage >= forest_cover) {
	        write("This is sustainable.");
	    } else {
	        write("This is not sustainable.");
	    }
	    do pause;
	}

	// Reflex to save simulation data to a CSV file in batch mode
	reflex save_to_csv when: is_batch and logged{
		if ((seasons> end_season ) or (length(land where each.grove)=0)){
			bool sustainable ;
			bool deforestation_status;
			write('\n------------------------');
         	write(self.name);
            if length(land where each.grove) = 0 {
               write('Total deforestation in Season: ' + (seasons) 
                  + ' Month: ' + (months));
                deforestation_status <- true;  
            }
            else {
			write('Passed '+end_season+' Seasons with \nForest percentage:'  + forestPercentage  
                  + ' \nBiomasses: ' 
                  + totalBiomass);
                 deforestation_status <- false;  
            }          
            
           if (forestPercentage >= forest_cover) {
	        write("This is sustainable.");
	        sustainable <- true;
	    } else {
	        write("This is not sustainable.");
	        sustainable <- false;
	    }
	 	    save [name,prob_respectful,deforestation_status,seasons,forestPercentage,totalBiomass,sustainable] to: save_file rewrite:false header:false;
	  		logged <- false;	
//            do die;
		}
	}
	
	// Reflex for the Forest Department to calculate institutional authorized minimum size when change_season
	reflex Forest_Department when:change_season{
		institutional_authorized_minimum_size <- [];
		ask herds{
			institutional_list << self.self_authorized_minimum_size;
		}
		institutional_authorized_minimum_size <- mean(institutional_list);
		
		//label grove to protect.
		ask land {
			if self.density <= institutional_authorized_minimum_size
			{
				self.is_protected <- true;
			}
			else
			{
				self.is_protected <- false;
			}
		}
	}
}

grid land width:grid_size height:grid_size neighbors:4{
	bool grove <- false;
	bool is_occupied <- false;
	bool is_protected <- false;
	float density <- 0.0;
	rgb tile_color <- #lightgreen; 
	rgb tree_color -> is_protected ?  #darkred : #darkgreen;  // Color for forested land, red if protected
	
	reflex spread when:!grove and change_month{
		list<land> forest_near_me <- neighbors where each.grove;
		list<float> density_list <- forest_near_me collect each.density;
		float prob <- length(forest_near_me)*(max_spread - min_spread);
		if flip(prob)
		{
			self.grove <- true;
			density <- sum(density_list)/4;
		}
	}
	
	reflex regen when:grove and change_month{
		density <- min([density + regen_rate,1.0]);
	}
	
	aspect testv{
	if !grove
		{
			draw square(2) color:tile_color;
		}
		else{
			draw square(2) color:tile_color;
			draw hexagon(0.75+density) color:tree_color;
		}
	}


}




species herds{
	bool respectful <- false;
	land my_land;
	list<land> memory ;
	list<float> memory_density ;
	float self_authorized_minimum_size <- 0.0;
	float eating_capicity <- eating_cap;
	land my_starting_month_land;
	float range <- perception_range;
	rgb vision -> self.respectful ? rgb(255, 127, 80,100) : rgb(255,255,0,100);
	init {
		my_land <- one_of(land);
		my_starting_month_land <- my_land;
		do update_loc;
		respectful <- flip(prob_respectful);
	}
	action update_loc{
		location <- my_land.location;
		ask my_land {
			is_occupied <- true;
		}
	} 	
	reflex move_by_month when: change_month{
		memory <+ my_starting_month_land;
//		calculating density of last month
		list<float> all_density <- (my_starting_month_land neighbors_at(range)) collect each.density; 
		memory_density << mean(all_density);
		self_authorized_minimum_size <- 1 - mean(memory_density);
//		write(self_authorized_minimum_size);
		my_starting_month_land <- my_land;
		
		
	}
	reflex next_season when: change_season{
		//	write(length(memory));
		memory <- [];
		memory_density <- [];
		self_authorized_minimum_size <- 0.0;
		
		
	}
	
	reflex moving{
		if my_land.grove{
			// if still in forest: stay to eat, no move
			return;
		}
		else
		{
			list<land> seeable_land <- (my_starting_month_land neighbors_at(range)) where (!each.is_occupied);
			if empty(seeable_land)
			{
//				stay cuz no where to go
				return;
			}
			// Identify forests with sufficient density
			list<land> seeable_forest <- seeable_land where ((each.grove) and (each.density>self_authorized_minimum_size));
			if respectful 
			{
				seeable_forest <- seeable_forest where !each.is_protected; // Respect protected lands if respectful
			}
			if !is_ruled
			{
				seeable_forest <- seeable_land where ((each.grove)); // Ignore protection if not ruled
			}
			my_land.is_occupied <- false;
 			if empty(seeable_forest)
 			{
 				list testv <- seeable_land where ((!each.grove));
 				my_land <- one_of( testv );
 				do update_loc;
 			}
 			else
 			{
 				my_land <- one_of(seeable_forest);
 				do update_loc;
 			}
					
		}
		
	}
	
	
	reflex eating{
		if my_land.grove{
			if my_land.density <= eating_capicity
			{
				my_land.grove <- false;
				my_land.density <- 0.0;
			}
			else
			{
				my_land.density <- my_land.density - eating_capicity;
			}
		}
	}
	
	


	aspect testv{
		
//		loop i over: self.memory {
//		    draw circle(range*2) color:rgb(128,0,128,20) at: i.location;
//		}
		draw polyline(self.memory,0.4) border:#black;
		if !empty(self.memory)
		{
			draw polyline([my_starting_month_land,last(self.memory)],0.4) border:#black;
		}
		
		if is_ruled{
			draw circle(range*2) color:vision at: my_starting_month_land.location;
		}
		else
		{
			draw circle(range*2) color:rgb(0,0,0,50) at: my_starting_month_land.location;
		}
		
		draw polyline([self.location,my_starting_month_land.location],0.3) border:#red;
		draw goat0_image_file size: 1.5;
	}
	
	aspect no_trail{
		
//		loop i over: self.memory {
//		    draw circle(range*2) color:rgb(128,0,128,20) at: i.location;
//		}
//		draw polyline(self.memory,0.4) border:#black;
//		if !empty(self.memory)
//		{
//			draw polyline([my_starting_month_land,last(self.memory)],0.4) border:#black;
//		}
//		
//		draw circle(range*2) color:rgb(255,255,0,100) at: my_starting_month_land.location;
//		draw polyline([self.location,my_starting_month_land.location],0.3) border:#red;
		draw goat0_image_file size: 1.5;
	}
}


experiment GUI_base virtual:true {
	parameter "Cycles per month: " var: cycle_per_month min: 1 max: 30 category: "Simulation";
	parameter "Months per grazing season: " var: month_per_season min: 1 max: 12 category: "Simulation";
	parameter "Last grazing season: " var: end_season min: 1 category: "Simulation";
	parameter "Grid size: " var: grid_size min: 10 max: 100 category: "Environment";
	parameter "Forest cover fraction: " var: forest_cover min: 0.0 max: 1.0 category: "Environment";
	parameter "Minimum tree spread probability: " var: min_spread min: 0.001 max: 0.01 category: "Forest";
	parameter "Maximum tree spread probability: " var: max_spread min: min_spread max: 0.2 category: "Forest";
	parameter "Forest regeneration rate: " var: regen_rate min: 0.01 max: 1.0 category: "Forest";
	parameter "Number of herds: " var: nb_herds min: 1 max: 100 category: "Herds";
	parameter "Perception range (m): " var: perception_range min: 1#m max: 50#m category: "Herds";
	parameter "Food per cycles " var: eating_cap min: 0.01 max: 1.0 category: "Herds";
	parameter "Probability of being respectful " var: prob_respectful min: 0.0 max: 1.0 category: "Herds";
	parameter "Regulation mode" var: is_ruled  category: "Herds";
	
	output {
		display Simulation {
			species land aspect: testv;
			species herds aspect: testv;
			overlay position: { 25#px,25#px} size: { 1 #px, 1 #px } background: # black border: #black rounded: false {
				 draw "Cycle: " + (cycle) + "     Season: " + (seasons)+ "     Month: " + (months) at: {0, 0} anchor: #top_left  color: #black font: font("Arial", 18, #bold);
				 rgb update_color <- change_month ? #red : #green;
				 draw rectangle(500#px, 40#px) at: {200#px, 10#px} wireframe: true color: update_color;
			}
		}
		
		display chart2v{
 		chart "Percentage of Groves in forest" type:series{
 			data "Patches of grove" value: length(land where each.grove);
 			data "Density of the forest" value: sum(land where each.grove collect each.density);
 			}}
 		display chartv{
		chart "Percentage of Groves in forest" type:pie{
			data "Patches of grove" value: length(land where each.grove);
			data "Pasture lands" value: length(land where !each.grove);
		}}	
	}
}

// if all shepherds were to enter the forest without any regulation? (PF_v2)
experiment "GUI No Regulation" parent:GUI_base {
	
	init {
		is_ruled <- false;
	}
	
}
// if all shepherds were to enter the forest without any regulation? (PF_v2)
experiment 'Run 20 Simulations No Regulation' type: batch repeat: 20 keep_seed:false  parallel: 10
   until: ((seasons> end_season ) or (length(land where each.grove)=0)) {
   	
   	init {
   		is_batch <- true;
   		is_ruled <- false;
   		save_file <- 'No_Regulation.csv';
		
   	}
   }

// if all shepherds were to follow their idea about the minimum size? (PF_v3)
experiment "GUI All Disrespectful" parent:GUI_base {
	
	parameter "Probability of being respectful " var: prob_respectful min: 0.0 max: 1.0 init:0.0 category: "Herds";

}

// if all shepherds were to follow their idea about the minimum size? (PF_v3)
experiment 'Run 20 Simulations All Disrespectful' type: batch repeat: 20 keep_seed:false  parallel: 10
   until: ((seasons> end_season ) or (length(land where each.grove)=0)) {
   	
   	init {
   		is_batch <- true;
   		is_ruled <- true;
		prob_respectful <- 0.0;
   		save_file <- 'All_Disrespectful.csv';
   		
   	}
   }


// if all shepherds were to follow the institutional minimum size? 
experiment "GUI All Respectful" parent:GUI_base {
	
	parameter "Probability of being respectful " var: prob_respectful min: 0.0 max: 1.0 init:1.0 category: "Herds";

}

// if all shepherds were to follow the institutional minimum size?
experiment 'Run 20 Simulations All Respectful' type: batch repeat: 20 keep_seed:false  parallel: 10
   until: ((seasons> end_season ) or (length(land where each.grove)=0)) {
   	
   	init {
   		is_batch <- true;
   		is_ruled <- true;
		prob_respectful <- 1.0;
   		save_file <- 'All_Respectful.csv';
   		
   	}
   }

/**
 * Name: Explore Respectful Rate Experiment
 * Description:
 * This experiment explores the relationship between the probability of a herd being respectful 
 * (adhering to the Forest Department's regulations) and the sustainability of the land (i.e., 
 * whether the forest remains intact by the end of the simulation). The experiment runs multiple 
 * simulations to determine the minimum probability of respectful behavior needed for the land 
 * to remain sustainable, where sustainability is defined as the forest cover at the end of the 
 * simulation being equal to or greater than the initial forest cover.
 * 
 * Method:
 * - The probability of a herd being respectful is varied from 0.0 to 1.0 in steps of 0.1.
 * - For each value of respectful probability, the simulation is repeated 5 times 
 *   to find the minimum threshold needed to keep the land sustainable.
 **/
experiment 'Explore Respectful Rate' type: batch repeat: 5 keep_seed:false  parallel: true
   until: ((seasons> end_season ) or (length(land where each.grove)=0)) {
   	parameter "Probability of being respectful " var: prob_respectful among:[0.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0] category: "Herds";
   	
   	
   	init {
   		is_batch <- true;
   		is_ruled <- true;
		prob_respectful <- 1.0;
   		save_file <- 'Explorer_RR.csv';
   		
   	}
   }



experiment GUI_No_trail title:'months' parent:GUI_base  {

	output {
		display Simulation {
			species land aspect: testv;
			species herds aspect: no_trail;
			overlay position: { 25#px,25#px} size: { 1 #px, 1 #px } background: # black border: #black rounded: false {
				 draw "Cycle: " + (cycle) + "     Season: " + (seasons)+ "     Month: " + (months) at: {0, 0} anchor: #top_left  color: #black font: font("Arial", 18, #bold);
				 rgb update_color <- change_month ? #red : #green;
				 draw rectangle(500#px, 40#px) at: {200#px, 10#px} wireframe: true color: update_color;
			}
			
		
	}	

	}

}




