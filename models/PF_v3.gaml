/**
 * Name: PFv3
 * Based on the internal empty template.
 * Author: Minh
 *
 * Description:
 * PFv3 is an updated version of the PF simulation model, designed to study the interaction 
 * between herds and forest ecosystems. It builds upon PFv2 by introducing new enhancements 
 * to simulate herd behavior with memory of past interactions and adaptive movement 
 * strategies.
 * 
 * New Key Features:
 * - Herds now use memory of past months to adapt their movements and behavior.
 * By the end of the each month, each shepherd computes a specific indicator, called
	“self-authorized minimum size”, set as the average of the density of the land that they can see in last day of each month. When the next
	grazing season starts, these individual memories are reset. 
 * - All the shepherd probit the herds eat any forest smaller than “self-authorized minimum size”.
 * - Added detailed visualization for tracking herd movements and forest state.
 * 
 * if all shepherds were to follow their idea about the minimum size?
 */


model PFv3

global
{
	int grid_size <- 50; 
	bool is_batch <- false;
	float forest_cover <- 0.3;
	int nb_herds <- 20;
	int end_season <- 50;
	float perception_range <- 4.5#m;
	float min_spread <- 0.0025;
	float max_spread <- 0.02;
	float regen_rate <- 0.07;
	float eating_cap <- 0.15;
	int cycle_per_month <- 10;
	int month_per_season <- 10;
	int months -> 1+ cycle div cycle_per_month;
	int seasons -> 1+ cycle div (cycle_per_month*month_per_season);
	bool change_month -> (cycle mod cycle_per_month = 0) and cycle!=0 ;
	bool change_season -> (cycle mod (cycle_per_month*month_per_season) = 0) and cycle!=0 ;
	
	image_file goat0_image_file <- image_file("../includes/icons/goat.png");
	
	init{
		do create_land;
		create herds number: nb_herds;
	}
	
	action create_land{
		int nb_tree <-  int(grid_size*grid_size*forest_cover);
		ask (nb_tree among land){
			self.forest <- true;
			density <- rnd(0.1, 1.0);
		}
		
	}
	reflex eat_clean when : length(land where each.forest)=0 and !is_batch{
			write('Total deforestation in '+ " Season: " + (seasons)+ " Month: " + (months) );
			write('Current Cycle : ' + cycle);
			do pause;
	}
	
	reflex survive when : seasons>end_season and !is_batch{
			write('Passed '+end_season+' Seasons with \nForest percentage:'  + (length(land where each.forest) / length(land)) 
                  + ' \nBiomasses: ' 
                  + sum(land where each.forest collect each.density));
            write('Current Cycle : ' + cycle);
			do pause;
	}

//	reflex test when : is_batch{
//		if ((seasons> end_season ) or (length(land where each.forest)=0)){
//			write('\n------------------------');
//         	write(self.name);
//            if length(land where each.forest) = 0 {
//               write('Total deforestation in Season: ' + (seasons) 
//                  + ' Month: ' + (months));
//            }
//            else {
//			write('Passed '+end_season+' Seasons with \nForest percentage:'  + (length(land where each.forest) / length(land)) 
//                  + ' \nBiomasses: ' 
//                  + sum(land where each.forest collect each.density));
//            }
//            write("Current Cycle "+cycle);
//            do pause;
//		}
//	} 
}

grid land width:grid_size height:grid_size neighbors:4{
	bool forest <- false;
	bool is_occupied <- false;
	bool is_protected <- false;
	float density <- 0.0;
	rgb my_color <- #lightgreen;
	
	reflex spread when:!forest and change_month{
		list<land> forest_near_me <- neighbors where each.forest;
		list<float> density_list <- forest_near_me collect each.density;
		float prob <- length(forest_near_me)*(max_spread - min_spread);
		if flip(prob)
		{
			self.forest <- true;
			density <- sum(density_list)/4;
		}
	}
	
	reflex regen when:forest and change_month{
		density <- min([density + regen_rate,1.0]);
	}
	
	aspect testv{
	if !forest
		{
			draw square(2) color:#lightgreen;
		}
		else{
			draw square(2) color:#lightgreen;
			draw hexagon(0.75+density) color:#darkgreen;
		}
	}


}




species herds{
	bool respectful <- false;
	land my_land;
	list<land> memory ;
	list<float> memory_density ;
	// The maximum size of the forest that the shepherd allow the herd to graze in the area
	float self_authorized_minimum_size <- 0.0;
	float eating_capicity <- eating_cap;
	land my_starting_month_land;
	float range <- perception_range;
	init {
		my_land <- one_of(land);
		my_starting_month_land <- my_land;
		do update_loc;
	}
	action update_loc{
		location <- my_land.location;
		ask my_land {
			is_occupied <- true;
		}
	} 	
	reflex move_by_month when: change_month{
		memory <+ my_starting_month_land;
		// Calculate the average density of neighboring cells within the perception range in last day of the months
		list<float> all_density <- (my_starting_month_land neighbors_at(range)) collect each.density; 
		memory_density << mean(all_density);
		
		// update self_authorized_minimum_size
		self_authorized_minimum_size <- 1 - mean(memory_density);
		
		// the sherpherd move to new land in the new month
		my_starting_month_land <- my_land;
		
		
	}
	reflex next_season when: change_season{
		//	write(length(memory));
		memory <- [];
		memory_density <- [];
		self_authorized_minimum_size <- 0.0;
		
		
	}
	
	reflex moving{
		if my_land.forest{
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
			list<land> seeable_forest <- seeable_land where ((each.forest) and (each.density>self_authorized_minimum_size));
			my_land.is_occupied <- false;
 			if empty(seeable_forest)
 			{
 				list testv <- seeable_land where ((!each.forest));
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
		if my_land.forest{
			if my_land.density <= eating_capicity
			{
				my_land.forest <- false;
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
		rgb vision <- self.respectful ? rgb(255, 127, 80,100) : rgb(255,255,0,100);
		draw circle(range*2) color:vision at: my_starting_month_land.location;
		draw polyline([self.location,my_starting_month_land.location],0.3) border:#red;
		draw goat0_image_file size: 1.5;
	}
	
	aspect no_trail{
		draw goat0_image_file size: 1.5;
	}
}





experiment GUI_No_law title:'months'  {
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
 		chart "Percentage of forest in lands" type:series{
 			data "Forest lands" value: length(land where each.forest);
 			data "Density of Forests" value: sum(land where each.forest collect each.density);
 			}}
 		display chartv{
		chart "Percentage of forest in lands" type:pie{
			data "Forest lands" value: length(land where each.forest);
			data "Pasture lands" value: length(land where !each.forest);
		
		}}		
	}

}


experiment GUI_No_trail title:'months'  {
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
 		display chart2v{
 		chart "Percentage of forest in lands" type:series{
 			data "Forest lands" value: length(land where each.forest);
 			data "Density of Forests" value: sum(land where each.forest collect each.density);
 			}}
 		 display chartv{
		chart "Percentage of forest in lands" type:pie{
			data "Forest lands" value: length(land where each.forest);
			data "Pasture lands" value: length(land where !each.forest);
		
		}}	
	}

}

// This part confused me so much
// because seem like when running parallel, batch experiment have tendency to randomly miss the catch from the until: clause.
// 2 of this below batch experiment have problems, which i have find a way to work around in the next vision.

experiment 'Run 10 Simulations' type: batch repeat: 10 keep_seed:false  parallel: 10 virtual:true
   until: (false) {
   	
   	init {
   		is_batch <- true;				
   	}
   }


experiment 'Run 10 Simulations 2' type: batch repeat: 10 keep_seed:false  parallel: 10 virtual:true
   until: ((seasons> end_season ) or (length(land where each.forest)=0)) {

   	init {
   		is_batch <- true;				
   	}

	reflex t {
		ask simulations{
			write('\n------------------------');
         	write(self.name);
            if length(land where each.forest) = 0 {
               write('Total deforestation in Season: ' + (seasons) 
                  + ' Month: ' + (months));
            }
            else {
			write('Passed '+end_season+' Seasons with \nForest percentage:'  + (length(land where each.forest) / length(land)) 
                  + ' \nBiomasses: ' 
                  + sum(land where each.forest collect each.density));
            }
		}
	}
   }


