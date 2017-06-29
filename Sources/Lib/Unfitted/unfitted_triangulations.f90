! Copyright (C) 2014 Santiago Badia, Alberto F. Martín and Javier Principe
!
! This file is part of FEMPAR (Finite Element Multiphysics PARallel library)
!
! FEMPAR is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! FEMPAR is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with FEMPAR. If not, see <http://www.gnu.org/licenses/>.
!
! Additional permission under GNU GPL version 3 section 7
!
! If you modify this Program, or any covered work, by linking or combining it 
! with the Intel Math Kernel Library and/or the Watson Sparse Matrix Package 
! and/or the HSL Mathematical Software Library (or a modified version of them), 
! containing parts covered by the terms of their respective licenses, the
! licensors of this Program grant you additional permission to convey the 
! resulting work. 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module unfitted_triangulations_names
  use fempar_names
  use level_set_functions_gallery_names
  use base_sparse_matrix_names
  use dof_import_names
  
  implicit none
# include "debug.i90"
  private

  ! Include the look-up tables 
# include "mc_tables_qua4.i90"
# include "mc_tables_hex8.i90"
  
  type, extends(cell_iterator_t) :: unfitted_cell_iterator_t
  
    private
    class(marching_cubes_t), pointer :: marching_cubes => NULL()
    
  contains

    ! Creation / deletion methods
    procedure :: create => unfitted_cell_iterator_create
    procedure :: free   => unfitted_cell_iterator_free
    
    ! Updater: to be called each time the lid changes
    procedure :: update_sub_triangulation    => unfitted_cell_iterator_update_sub_triangulation

    ! TODO this one should be private in the future
    ! Now it is public because the fe iterator uses it
    ! The goal is that the fe iterator does not assume that the mc algorithm is used to subdivide the elements
    ! Do not forget in the future to remove it also from cell_iterator_t
    procedure :: get_mc_case   => unfitted_cell_iterator_get_mc_case
    
    ! Getters related with the subcells
    procedure :: get_number_of_subcells      => unfitted_cell_iterator_get_number_of_subcells
    procedure :: get_number_of_subcell_nodes => unfitted_cell_iterator_get_number_of_subcell_nodes
    procedure :: get_phys_coords_of_subcell  => unfitted_cell_iterator_get_phys_coords_of_subcell
    procedure :: get_ref_coords_of_subcell   => unfitted_cell_iterator_get_ref_coords_of_subcell
    
    ! Getters related with the subfaces
    procedure :: get_number_of_subfaces      => unfitted_cell_iterator_get_number_of_subfaces
    procedure :: get_number_of_subface_nodes => unfitted_cell_iterator_get_number_of_subface_nodes
    procedure :: get_phys_coords_of_subface  => unfitted_cell_iterator_get_phys_coords_of_subface
    procedure :: get_ref_coords_of_subface   => unfitted_cell_iterator_get_ref_coords_of_subface
    
    ! Checkers
    procedure :: is_cut      => unfitted_cell_iterator_is_cut
    procedure :: is_interior => unfitted_cell_iterator_is_interior
    procedure :: is_exterior => unfitted_cell_iterator_is_exterior
    procedure :: is_interior_subcell => unfitted_cell_iterator_is_interior_subcell
    procedure :: is_exterior_subcell => unfitted_cell_iterator_is_exterior_subcell

    ! Private TBPs
    procedure, non_overridable, private :: get_number_of_subnodes         => unfitted_cell_iterator_get_number_of_subnodes
    procedure, non_overridable, private :: subcell_has_been_reoriented    => unfitted_cell_iterator_subcell_has_been_reoriented
    procedure, non_overridable, private :: subface_touches_interior_reoriented_subcell => unfitted_cell_iterator_subface_touches_reoriented_subcell

    
  end type unfitted_cell_iterator_t

  ! We need this to create a par fe space in marching_cubes_t to hold a discrete levelset function
  type, extends(standard_l1_coarse_fe_handler_t) :: mc_dummy_coarse_fe_handler_t
    contains
      procedure :: get_num_coarse_dofs       => mc_dummy_coarse_fe_handler_get_num_coarse_dofs
      procedure :: setup_constraint_matrix   => mc_dummy_coarse_fe_handler_setup_constraint_matrix
      procedure :: setup_weighting_operator  => mc_dummy_coarse_fe_handler_setup_weighting_operator
  end type mc_dummy_coarse_fe_handler_t

  ! We need this to create a fe space in marching_cubes_t to hold a discrete levelset function
  type, extends(conditions_t) :: mc_dummy_conditions_t
    contains
      procedure :: get_number_components  => mc_dummy_conditions_get_number_components
      procedure :: get_components_code    => mc_dummy_conditions_get_components_code
      procedure :: get_function           => mc_dummy_conditions_get_function
  end type mc_dummy_conditions_t

  type :: marching_cubes_t
    private

    ! The underlying triangulation
    class(base_static_triangulation_t), pointer :: triangulation => null()

    ! The level set funciton
    class(level_set_function_t), pointer :: level_set_function => null()

    ! The discrete version of the level-set function
    type(fe_function_t) :: fe_levelset

    ! The fe space associated with the discrete version of the levelset function
    class(serial_fe_space_t), allocatable :: fe_space
    type(block_layout_t)                  :: block_layout

    ! Auxiliary dummy things to create the fe space for the levelset
    type(p_reference_fe_t), allocatable :: reference_fes(:) 
    type(mc_dummy_coarse_fe_handler_t)  :: dummy_coarse_handler
    type(p_l1_coarse_fe_handler_t), allocatable  :: dummy_coarse_handlers(:)

    ! Look up-tables (precomputed off-line, for each cell type)
    integer(ip)                :: mc_table_num_cases
    integer(ip)                :: mc_table_max_num_subcells
    integer(ip)                :: mc_table_max_num_subfaces
    integer(ip)                :: mc_table_max_num_cut_edges
    integer(ip)                :: mc_table_num_nodes_subcell
    integer(ip)                :: mc_table_num_nodes_subface
    integer(ip),   allocatable :: mc_table_num_subcells_per_case(:)
    integer(ip),   allocatable :: mc_table_num_subfaces_per_case(:)
    integer(ip),   allocatable :: mc_table_num_cut_edges_per_case(:)
    integer(ip),   allocatable :: mc_table_inout_subcells_per_case(:,:)
    integer(ip),   allocatable :: mc_table_subcell_node_ids_per_case(:,:,:)
    integer(ip),   allocatable :: mc_table_subface_node_ids_per_case(:,:,:)
    logical :: mc_tables_init = .false.

    ! Info related to cut cells on this triangulation (this is computed at runtime)
    integer(ip),   allocatable :: mc_case_per_cell(:)
    integer(ip),   allocatable :: mc_ptr_to_intersections(:)
    type(point_t), allocatable :: mc_intersection_points(:)
    logical :: mc_runtime_init = .false.

    ! Info related to the sub-tessellation
    ! When located on a cell, and the sub-triangulation is updated,
    ! these memeber variables contain info about the current sub-tessalation
    integer(ip),        allocatable :: subcells_nodal_connectivities(:,:)
    integer(ip),        allocatable :: subfaces_nodal_connectivities(:,:)
    type(point_t),      allocatable :: subnodes_ref_coords(:)
    logical,            allocatable :: subcell_has_been_reoriented(:)
    
    ! Auxiliary work data
    type(quadrature_t), allocatable :: subnodes_nodal_quadratures(:)
    type(fe_map_t),     allocatable :: subnodes_fe_maps(:)

  contains

    ! Creation / deletion methods
    procedure                  :: create                        => marching_cubes_create
    procedure                  :: free                          => marching_cubes_free
    
    ! Polymorphic creation of the iterator to be used only within this module
    procedure, non_overridable, private :: create_cell_iterator          => marching_cubes_create_cell_iterator

    ! Non polimorphic creation / deletion  of iterators to be used only within this module
    procedure, non_overridable, private :: create_unfitted_cell_iterator => marching_cubes_create_unfitted_cell_iterator
    procedure, non_overridable, private :: free_unfitted_cell_iterator   => marching_cubes_free_unfitted_cell_iterator

    ! Getters
    procedure, non_overridable :: get_num_cut_cells             => marching_cubes_get_num_cut_cells
    procedure, non_overridable :: get_num_interior_cells        => marching_cubes_get_num_interior_cells
    procedure, non_overridable :: get_num_exterior_cells        => marching_cubes_get_num_exterior_cells
    procedure, non_overridable :: get_max_num_subcells_in_cell  => marching_cubes_get_max_num_subcells_in_cell
    procedure, non_overridable :: get_max_num_nodes_in_subcell  => marching_cubes_get_max_num_nodes_in_subcell
    procedure, non_overridable :: get_total_num_of_subcells     => marching_cubes_get_total_num_of_subcells
    procedure, non_overridable :: get_max_num_subfaces_in_cell  => marching_cubes_get_max_num_subfaces_in_cell
    procedure, non_overridable :: get_max_num_nodes_in_subface  => marching_cubes_get_max_num_nodes_in_subface
    procedure, non_overridable :: get_total_num_of_subfaces     => marching_cubes_get_total_num_of_subfaces
    procedure, non_overridable :: get_max_num_subnodes_in_cell  => marching_cubes_get_max_num_subnodes_in_cell
    procedure, non_overridable :: get_num_dimensions            => marching_cubes_get_num_dimensions
    
    ! Getters related with the mc algorithm
    procedure, non_overridable :: get_num_mc_cases              => marching_cubes_get_num_mc_cases
    procedure, non_overridable :: get_num_subcells_mc_case      => marching_cubes_get_num_subcells_mc_case
    procedure, non_overridable :: get_num_subfaces_mc_case      => marching_cubes_get_num_subfaces_mc_case
    
    ! Printers
    procedure :: print                     => marching_cubes_print
    
    ! Private TBP
    procedure, non_overridable, private :: fulfills_assumptions           => marching_cubes_fulfills_assumptions
    procedure, non_overridable, private :: mc_tables_create               => marching_cubes_mc_tables_create
    procedure, non_overridable, private :: mc_tables_free                 => marching_cubes_mc_tables_free
    procedure, non_overridable, private :: discrete_levelset_create       => marching_cubes_discrete_levelset_create
    procedure, non_overridable, private :: discrete_levelset_free         => marching_cubes_discrete_levelset_free
    procedure, non_overridable, private :: discrete_levelset_fix          => marching_cubes_discrete_levelset_fix
    procedure, non_overridable, private :: discrete_levelset_comm         => marching_cubes_discrete_levelset_comm
    procedure, non_overridable, private :: mc_runtime_info_create         => marching_cubes_mc_runtime_info_create
    procedure, non_overridable, private :: mc_runtime_info_free           => marching_cubes_mc_runtime_info_free
    procedure, non_overridable, private :: subnodes_data_create           => marching_cubes_subnodes_data_create
    procedure, non_overridable, private :: subnodes_data_free             => marching_cubes_subnodes_data_free
    

  end type marching_cubes_t

  type, extends(serial_triangulation_t) :: serial_unfitted_triangulation_t
    private
      type(marching_cubes_t) :: marching_cubes
    contains

      ! Creation / deletion methods
      generic             :: create                       => sut_create
      procedure           :: free                         => sut_free
      procedure,  private :: serial_triangulation_create  => sut_serial_triangulation_create
      procedure,  private :: sut_create

      ! Generate iterator by overloading the procedure of the father
      procedure :: create_cell_iterator => sut_create_cell_iterator

      ! Getters
      procedure, non_overridable :: get_marching_cubes            => sut_get_marching_cubes
      procedure, non_overridable :: get_num_cut_cells             => sut_get_num_cut_cells
      procedure, non_overridable :: get_num_interior_cells        => sut_get_num_interior_cells
      procedure, non_overridable :: get_num_exterior_cells        => sut_get_num_exterior_cells
      procedure, non_overridable :: get_max_num_subcells_in_cell  => sut_get_max_num_subcells_in_cell
      procedure, non_overridable :: get_max_num_nodes_in_subcell  => sut_get_max_num_nodes_in_subcell
      procedure, non_overridable :: get_total_num_of_subcells     => sut_get_total_num_of_subcells
      procedure, non_overridable :: get_max_num_subfaces_in_cell  => sut_get_max_num_subfaces_in_cell
      procedure, non_overridable :: get_max_num_nodes_in_subface  => sut_get_max_num_nodes_in_subface
      procedure, non_overridable :: get_total_num_of_subfaces     => sut_get_total_num_of_subfaces
      procedure, non_overridable :: get_max_num_subnodes_in_cell  => sut_get_max_num_subnodes_in_cell

      ! TODO this getters should be removed in the future
      ! Now the fe space uses them.
      ! The goal is that the fe space does not assume that the tesselation algorithm is the mc algorithm
      procedure, non_overridable :: get_num_mc_cases              => sut_get_num_mc_cases
      procedure, non_overridable :: get_num_subcells_mc_case      => sut_get_num_subcells_mc_case
      procedure, non_overridable :: get_num_subfaces_mc_case      => sut_get_num_subfaces_mc_case

      ! Printers
      procedure :: print                     => sut_print

  end type serial_unfitted_triangulation_t

  type, extends(par_triangulation_t) :: par_unfitted_triangulation_t
    private
      type(marching_cubes_t) :: marching_cubes
    contains

      ! Creation / deletion methods
      generic             :: create                       => put_create
      procedure           :: free                         => put_free
      procedure,  private :: par_triangulation_create     => put_par_triangulation_create
      procedure,  private :: put_create

      ! Generate iterator by overloading the procedure of the father
      procedure :: create_cell_iterator          => put_create_cell_iterator

      ! Getters
      procedure, non_overridable :: get_marching_cubes            => put_get_marching_cubes
      procedure, non_overridable :: get_num_cut_cells             => put_get_num_cut_cells
      procedure, non_overridable :: get_num_interior_cells        => put_get_num_interior_cells
      procedure, non_overridable :: get_num_exterior_cells        => put_get_num_exterior_cells
      procedure, non_overridable :: get_max_num_subcells_in_cell  => put_get_max_num_subcells_in_cell
      procedure, non_overridable :: get_max_num_nodes_in_subcell  => put_get_max_num_nodes_in_subcell
      procedure, non_overridable :: get_total_num_of_subcells     => put_get_total_num_of_subcells
      procedure, non_overridable :: get_max_num_subfaces_in_cell  => put_get_max_num_subfaces_in_cell
      procedure, non_overridable :: get_max_num_nodes_in_subface  => put_get_max_num_nodes_in_subface
      procedure, non_overridable :: get_total_num_of_subfaces     => put_get_total_num_of_subfaces
      procedure, non_overridable :: get_max_num_subnodes_in_cell  => put_get_max_num_subnodes_in_cell

      ! TODO this getters should be removed in the future
      ! Now the fe space uses them.
      ! The goal is that the fe space does not assume that the tesselation algorithm is the mc algorithm
      procedure, non_overridable :: get_num_mc_cases              => put_get_num_mc_cases
      procedure, non_overridable :: get_num_subcells_mc_case      => put_get_num_subcells_mc_case
      procedure, non_overridable :: get_num_subfaces_mc_case      => put_get_num_subfaces_mc_case

      ! Printers
      procedure :: print                     => put_print

  end type par_unfitted_triangulation_t

  ! Derived types
  public :: unfitted_cell_iterator_t
  public :: marching_cubes_t 
  public :: serial_unfitted_triangulation_t
  public :: par_unfitted_triangulation_t

contains

#include "sbm_unfitted_cell_iterator.i90"
#include "sbm_marching_cubes.i90"
#include "sbm_serial_unfitted_triangulation.i90"
#include "sbm_par_unfitted_triangulation.i90"

end module unfitted_triangulations_names

