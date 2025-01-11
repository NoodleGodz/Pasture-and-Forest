/**
 * Name: PFv1
 *
 * Based on: Internal empty template.
 * Author: Minh
 * 
 * Description:
 * This is the first iteration of the Pasture and Forest Project (PFv1), 
 * designed to simulate the interaction between forest lands and herds.  
 * 
 * Features Implemented:
 * - **Grid-based land model**:
 *   - Lands are represented as cells in a 2D grid with specific attributes:
 *     - `forest`: Indicates if the cell is forested.
 *     - `is_occupied`: Indicates if the cell is occupied by a herd.
 *   - Forest spread based on 4 neighboring forested cells.
 * - **Herd dynamics**:
 *   - Herds move around the grid based on perception and available unoccupied lands.
 *   - Herds prefer forested cells but can settle in pasture lands if no forest is visible.
 * - **Visualization**:
 *   - Grid cells are visually represented using shapes and colors:
 *     - Pasture lands: Light green squares.
 *     - Forested lands: Light green squares overlaid with dark green hexagons.
 *   - Herds are represented as circles with a visual indication of their perception range.
 * - **Experiments and Output**:
 *   - Two display panels:
 *     1. Visualization of land and herds (`minh`).
 *     2. Dynamic charts showing the proportion and evolution of forested and pasture lands:
 * 
 * Key Parameters:
 * - `grid_size`: Determines the dimensions of the land grid.
 * - `forest_cover`: Sets the initial proportion of forested lands.
 * - `nb_herds`: Number of herds initialized in the environment.
 * - `perception_range`: The range within which herds can perceive and react to their surroundings.
 * - `min_spread` and `max_spread`: Parameters controlling the probability of forest spreading.
 * 
*/


model PFv1

global
{
	int grid_size <- 50; 
	float forest_cover <- 0.3;
	int nb_herds <- 15;
	float perception_range <- 4.5#m;
	float min_spread <- 0.0025;
	float max_spread <- 0.02;
	
	
	init{
		do create_land;
		create herds number: nb_herds;
	}
	
//	Ensure the percentage forest in the grid to be exactly var: forest_cover
	action create_land{
		int nb_tree <-  int(grid_size*grid_size*forest_cover);
		ask (nb_tree among land){
			self.forest <- true;
		}
		
	}
}

grid land width:grid_size height:grid_size neighbors:4{
	bool forest <- false;
	bool is_occupied <- false;
	bool is_protected <- false;
	rgb my_color <- #lightgreen;
	
	reflex spread when:!forest{
		float prob <- length(neighbors where each.forest)*(max_spread - min_spread);
		if flip(prob)
		{
			self.forest <- true;
		}
	}

	aspect testv{
	if !forest
		{
			draw square(2) color:#lightgreen;
		}
		else{
			draw square(2) color:#lightgreen;
			draw hexagon(1.5) color:#darkgreen;
		}
	}
}


/**
 * Species: herds
 * Description:
 * This block defines the behavior and attributes of herds in the simulation. 
 * Herds interact with the land grid, move within a defined perception range, 
 * and exhibit a preference for forested cells when choosing their new location. 
 * 
 * Attributes:
 * - `my_land`: Refers to the current land cell occupied by the herd.
 * - `range`: The perception range within which the herd can observe surrounding cells.
 * 
 * Init:
 * - Each herd is assigned to a random land cell.
 * 
 * 
 * Reflexes:
 * **moving**:
 *    - Defines the movement behavior of the herd:
 *      - Identifies all neighboring cells within its perception range (`seeable_land`) 
 *        that are not occupied (`!each.is_occupied`).
 *      - If no such cells are available, the herd stays in its current position.
 *      - If available:
 *        - The current cell (`my_land`) is marked as unoccupied, and its forest 
 *          attribute is reset (`forest <- false`).
 *        - Among visible cells:
 *          - If forested cells are available (`seeable_forest`), the herd moves to one of them.
 *          - Otherwise, it moves to any available pasture cell in its perception range.
 *        - Calls `update_loc` to update its new position.
 */

species herds{
	bool respectful <- true;
	land my_land;
	float range <- perception_range;
	init {
		my_land <- one_of(land);
		do update_loc;
	}
	action update_loc{
		location <- my_land.location;
		ask my_land {
			is_occupied <- true;
		}
	}
	reflex moving{
		list<land> seeable_land <- (my_land neighbors_at(range)) where (!each.is_occupied) ;
		if empty(seeable_land)
		{
//			stay at my cell
			return;
		}
		else
		{
			ask my_land 
			{
			is_occupied <- false;
			forest <- false;
			}
			list<land> seeable_forest <- seeable_land where (each.forest);
			if empty(seeable_forest)
			{
				my_land <- one_of(seeable_land);
				do update_loc;
			}
			else
			{
				my_land <- one_of(seeable_forest);
				do update_loc;
			}
			
		
		}
	
	}
	aspect testv{
		draw circle(0.5) color:#white;
		draw circle(range) color:rgb(255,255,0,100);	
	}
}





experiment test {
	output {
		display minh {
			species land aspect: testv;
			species herds aspect: testv;
		
	}	
	display chartv{
		chart "Percentage of forest in lands" type:pie{
			data "Forest lands" value: length(land where each.forest);
			data "Pasture lands" value: length(land where !each.forest);
		
		}

	}
		display chart2v{
		chart "Percentage of forest in lands 3" type:series{
			data "Forest lands" value: length(land where each.forest);
			data "Pature lands" value: length(land where !each.forest);
			}}
	}

}


