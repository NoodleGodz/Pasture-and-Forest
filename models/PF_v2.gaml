/**
 * Name: PFv2
 * Based on the internal empty template.
 * Author: Minh
 *
 * Description:
 * PFv2 is a simulation model designed to study the interaction between herds and forest ecosystems. 
 * It builds upon PFv1 by introducing new enhancements to regulate herd behavior and ensure 
 * more realistic modeling of environmental and ecological changes.
 * 
 * New Key Features:
 * - Implements land regeneration and forest density changes with monthly cycles.
 * - Allows herds to memorize their starting location each month for more structured movement (Simulated where the Shepherds move each month).
 * - The herds can move around in range when Shepherd stand ing
 * - Introduces a visual representation of herd trails and movements across seasons.
 * - Tracks simulation progress via overlays.
 * 
 * IF all shepherds were to enter the forest without any regulation:
 * 
 */


model PFv2

global
{
	int grid_size <- 50; 
	float forest_cover <- 0.3;
	int nb_herds <- 20;
	float perception_range <- 4.5#m;
	float min_spread <- 0.0025;
	float max_spread <- 0.02;
	
//	The density that the forest recover after each month
	float regen_rate <- 0.07;
	
//	The density that the herds eat after each cycle
	float eating_cap <- 0.15;
	
// **Simulation update: **:
// - Monthly and seasonal cycle tracking (`change_month`, `change_season`).

	int cycle_per_month <- 10;
	int month_per_season <- 10;
	int months -> 1+ cycle div cycle_per_month;
	int seasons -> 1+ cycle div (cycle_per_month*month_per_season);
	bool change_month -> (cycle mod cycle_per_month = 0) and cycle!=0 ;
	bool change_season -> (cycle mod (cycle_per_month*month_per_season) = 0) and cycle!=0 ;
	int end_season <- 50;
	
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
// - Simulation halts automatically upon total deforestation or after a predefined number of seasons.
	reflex eat_clean when : length(land where each.forest)=0{
			write('Total deforestation in '+ " Season: " + (seasons)+ " Month: " + (months) );
			do pause;
	}
	
	reflex survive when : seasons>end_season{
			write('Passed '+end_season+' Seasons with \nForest percentage:'  + (length(land where each.forest) / length(land)) 
                  + ' \nBiomasses: ' 
                  + sum(land where each.forest collect each.density));
			do pause;
	}
	
}

grid land width:grid_size height:grid_size neighbors:4{
	bool forest <- false;
	bool is_occupied <- false;
	bool is_protected <- false;
	// forest density as a variable affecting regeneration and grazing.
	float density <- 0.0;
	rgb my_color <- #lightgreen;
	
// Reflex: Forest spreads to nearby non-forest cells based on neighboring forest density.
	reflex spread when:!forest and change_month{
		list<land> forest_near_me <- neighbors where each.forest;
		list<float> density_list <- forest_near_me collect each.density;
		float prob <- length(forest_near_me)*(max_spread - min_spread);
		if flip(prob)
		{
			self.forest <- true;
			density <- sum(density_list)/4; // Set density as average of neighbors.
		}
	}
	
// Reflex: Forest regenerates density over time, capped at 1.0.
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
			// Represent the forest density
			draw hexagon(0.75+density) color:#darkgreen;
		}
	}


}


/* 
 * - Herds now record and utilize their monthly starting positions to influence movement patterns.
 * - Movement rules to stay within the perception range, reducing random movement.
 * 
 */
species herds{
	bool respectful <- true;
	land my_land;
    list<land> memory; // Tracks visited locations during a season.
    list<float> memory_density; // Tracks forest densities of visited locations.
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
	// Tracks starting location for each month
	reflex move_by_month when: change_month{
		memory <+ my_starting_month_land; // Add current starting point to memory.
		my_starting_month_land <- my_land; // Update the starting location for the new month.
		
		
	}
	reflex next_season when: change_season{

		memory <- [];
		
	}
	
	reflex moving{
		if my_land.forest{
			// If still in a forest, stay and eat.
			return;
		}
		else
		{
			// Identify nearby unoccupied land within range.
			list<land> seeable_land <- (my_starting_month_land neighbors_at(range)) where (!each.is_occupied);
			if empty(seeable_land)
			{
//				stay cuz no where to go
				return;
			}
			list<land> seeable_forest <- seeable_land where (each.forest);
			my_land.is_occupied <- false;
 			if empty(seeable_forest)
 			{
 				my_land <- one_of(seeable_land);
 				// Move to random unoccupied land if no forested land is visible
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
				// If density is low, eat the entire forest.
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
		draw polyline(self.memory,0.4) border:#black; // Draw memory trail
		if !empty(self.memory)
		{
			draw polyline([my_starting_month_land,last(self.memory)],0.4) border:#black;
		}
		
		draw circle(range*2) color:rgb(255,255,0,100) at: my_starting_month_land.location;  // Draw perception range.
		draw polyline([self.location,my_starting_month_land.location],0.3) border:#red;  // Line to starting location.
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

/* Insert your model definition here */



