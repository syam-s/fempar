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
module test_poisson_error_estimator_driver_names
  use fempar_names
  use test_poisson_error_estimator_params_names
  use poisson_cG_discrete_integration_names
  use poisson_conditions_names
  use poisson_analytical_functions_names
  use poisson_cG_error_estimator_names
  use IR_Precision ! VTK_IO
  use Lib_VTK_IO   ! VTK_IO
    
#define ENABLE_MKL = .true.
  
# include "debug.i90"

  implicit none
  private
  
  type test_poisson_error_estimator_driver_t 
     private 
     
     type(test_poisson_error_estimator_params_t) :: test_params
     type(ParameterList_t)                       :: parameter_list
     
     type(p4est_serial_triangulation_t)          :: triangulation
     
     type(serial_fe_space_t)                     :: fe_space 
     type(p_reference_fe_t), allocatable         :: reference_fes(:) 
     
     type(poisson_cG_discrete_integration_t)     :: poisson_cG_integration
     type(poisson_conditions_t)                  :: poisson_conditions
     type(poisson_analytical_functions_t)        :: poisson_analytical_functions
     type(poisson_cG_error_estimator_t)          :: poisson_cG_error_estimator
     
     type(fe_affine_operator_t)                  :: fe_affine_operator
     
#ifdef ENABLE_MKL
     type(direct_solver_t)                       :: direct_solver
#else
     type(iterative_linear_solver_t)             :: iterative_linear_solver
#endif
     
     type(fe_function_t)                         :: solution
     
   contains
     procedure          :: run_simulation
     procedure, private :: parse_command_line_parameters
     procedure, private :: setup_triangulation
     procedure, private :: set_cells_for_uniform_refinement
     procedure, private :: setup_reference_fes
     procedure, private :: setup_fe_space
     procedure, private :: refine_and_coarsen
     procedure, private :: setup_system
     procedure, private :: setup_solver
     procedure, private :: assemble_system
     procedure, private :: solve_system
     procedure, private :: check_solution
     procedure, private :: write_solution
     procedure, private :: free
  end type test_poisson_error_estimator_driver_t

  public :: test_poisson_error_estimator_driver_t

contains

  subroutine parse_command_line_parameters(this)
    implicit none
    class(test_poisson_error_estimator_driver_t ), intent(inout) :: this
    call this%test_params%create()
    call this%test_params%parse(this%parameter_list)
  end subroutine parse_command_line_parameters
  
  subroutine setup_triangulation(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    class(vef_iterator_t), allocatable :: vef
    integer(ip)                        :: i
    call this%triangulation%create(this%parameter_list)
    if ( .not. this%test_params%get_use_void_fes() ) then
      call this%triangulation%create_vef_iterator(vef)
      do while ( .not. vef%has_finished() )
        if(vef%is_at_boundary()) then
          call vef%set_set_id(1)
        else
          call vef%set_set_id(0)
        end if
        call vef%next()
      end do
      call this%triangulation%free_vef_iterator(vef)
    end if
    call this%set_cells_for_uniform_refinement()
    call this%triangulation%refine_and_coarsen()
    call this%triangulation%clear_refinement_and_coarsening_flags()
  end subroutine setup_triangulation
  
  subroutine set_cells_for_uniform_refinement(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    class(cell_iterator_t), allocatable :: cell
    call this%triangulation%create_cell_iterator(cell)
    do while ( .not. cell%has_finished() )
      call cell%set_for_refinement()
      call cell%next()
    end do
    call this%triangulation%free_cell_iterator(cell)
  end subroutine set_cells_for_uniform_refinement
  
  subroutine setup_reference_fes(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    integer(ip)                         :: istat
    class(cell_iterator_t), allocatable :: cell
    class(reference_fe_t) , pointer     :: reference_fe_geo
    allocate(this%reference_fes(1), stat=istat)
    check(istat==0)
    call this%triangulation%create_cell_iterator(cell)
    reference_fe_geo => cell%get_reference_fe()
    this%reference_fes(1) =  make_reference_fe ( topology   = reference_fe_geo%get_topology(),           &
                                                 fe_type    = fe_type_lagrangian,                        &
                                                 num_dims   = this%triangulation%get_num_dims(),         &
                                                 order      = this%test_params%get_reference_fe_order(), &
                                                 field_type = field_type_scalar,                         &
                                                 conformity = .true. )
    call this%triangulation%free_cell_iterator(cell)
  end subroutine setup_reference_fes

  subroutine setup_fe_space(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    call this%poisson_analytical_functions%set_num_dims(this%triangulation%get_num_dims())
    call this%poisson_conditions%set_boundary_function(this%poisson_analytical_functions%get_boundary_function())
    call this%fe_space%create( triangulation       = this%triangulation, &
                               reference_fes       = this%reference_fes, &
                               conditions          = this%poisson_conditions )
    call this%fe_space%set_up_cell_integration()
  end subroutine setup_fe_space
  
  subroutine refine_and_coarsen(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    integer(ip) :: i
    real(rp)    :: global_estimate, global_true_error, global_effectivity
    call this%poisson_cG_error_estimator%create(this%fe_space,this%parameter_list)
    call this%poisson_cG_error_estimator%set_analytical_functions(this%poisson_analytical_functions)
    call this%poisson_cG_error_estimator%set_fe_function(this%solution)
    
    do i = 1,5
      
      if ( i > 1 ) then
        call this%set_cells_for_uniform_refinement()
        call this%triangulation%refine_and_coarsen()
        call this%fe_space%refine_and_coarsen( this%solution )
        call this%fe_space%set_up_cell_integration()
        call this%fe_space%interpolate_dirichlet_values(this%solution)
        call this%fe_affine_operator%reallocate_after_remesh()
        call this%assemble_system()
        call this%direct_solver%replace_matrix( matrix = this%fe_affine_operator%get_matrix(), & 
                                                same_nonzero_pattern = .false. )
        call this%solve_system()
        call this%check_solution()
      end if
      
      call this%poisson_cG_error_estimator%compute_local_estimates()
      call this%poisson_cG_error_estimator%compute_global_estimate()
      
      call this%poisson_cG_error_estimator%compute_local_true_errors()
      call this%poisson_cG_error_estimator%compute_global_true_error()
      
      call this%poisson_cG_error_estimator%compute_local_effectivities()
      call this%poisson_cG_error_estimator%compute_global_effectivity()
      
      global_estimate    = this%poisson_cG_error_estimator%get_global_estimate()
      global_true_error  = this%poisson_cG_error_estimator%get_global_true_error()
      global_effectivity = this%poisson_cG_error_estimator%get_global_effectivity()
      
      write(*,'(a20,e32.25)') 'global_estimate:'  , global_estimate
      write(*,'(a20,e32.25)') 'global_true_error:', global_true_error
      write(*,'(a20,e32.25)') 'global_true_error:', global_effectivity
      
    end do
    
  end subroutine refine_and_coarsen
  
  subroutine setup_system (this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    call this%poisson_cG_integration%set_analytical_functions(this%poisson_analytical_functions)
    call this%fe_affine_operator%create ( sparse_matrix_storage_format      = csr_format,                               &
                                          diagonal_blocks_symmetric_storage = [ .true. ],                               &
                                          diagonal_blocks_symmetric         = [ .true. ],                               &
                                          diagonal_blocks_sign              = [ SPARSE_MATRIX_SIGN_POSITIVE_DEFINITE ], &
                                          fe_space                          = this%fe_space,                            &
                                          discrete_integration              = this%poisson_cG_integration )
    call this%solution%create(this%fe_space)
    call this%fe_space%interpolate_dirichlet_values(this%solution)
    call this%poisson_cG_integration%set_fe_function(this%solution)
  end subroutine setup_system
  
  subroutine setup_solver (this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    integer :: FPLError
    type(parameterlist_t) :: parameter_list
    integer :: iparm(64)
    class(matrix_t), pointer       :: matrix

    call parameter_list%init()
#ifdef ENABLE_MKL
    FPLError = parameter_list%set(key = direct_solver_type                  , value = pardiso_mkl)
    FPLError = FPLError + parameter_list%set(key = pardiso_mkl_matrix_type  , value = pardiso_mkl_spd)
    FPLError = FPLError + parameter_list%set(key = pardiso_mkl_message_level, value = 0)
    iparm = 0
    FPLError = FPLError + parameter_list%set(key = pardiso_mkl_iparm        , value = iparm)
    assert(FPLError == 0)
    
    call this%direct_solver%set_type_from_pl(parameter_list)
    call this%direct_solver%set_parameters_from_pl(parameter_list)
    
    matrix => this%fe_affine_operator%get_matrix()
    select type(matrix)
    class is (sparse_matrix_t)
       call this%direct_solver%set_matrix(matrix)
    class DEFAULT
       assert(.false.)
    end select
#else
    FPLError = parameter_list%set(key = ils_rtol, value = 1.0e-12_rp)
    FPLError = parameter_list%set(key = ils_max_num_iterations, value = 5000)
    assert(FPLError == 0)
    call this%iterative_linear_solver%create(this%fe_space%get_environment())
    call this%iterative_linear_solver%set_type_from_string(cg_name)
    call this%iterative_linear_solver%set_parameters_from_pl(parameter_list)
    call this%iterative_linear_solver%set_operators(this%fe_affine_operator%get_tangent(), .identity. this%fe_affine_operator) 
#endif
    call parameter_list%free()
    
  end subroutine setup_solver
  
  subroutine assemble_system (this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    class(matrix_t)                  , pointer       :: matrix
    class(vector_t)                  , pointer       :: rhs
    call this%fe_affine_operator%compute()
  end subroutine assemble_system
  
  subroutine solve_system(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    class(vector_t)                         , pointer       :: dof_values
    dof_values => this%solution%get_free_dof_values()
#ifdef ENABLE_MKL    
    call this%direct_solver%solve(this%fe_affine_operator%get_translation(), dof_values)
#else
    call this%iterative_linear_solver%solve(this%fe_affine_operator%get_translation(), &
                                            dof_values)
#endif
    call this%fe_space%update_hanging_dof_values(this%solution)
  end subroutine solve_system
  
  subroutine check_solution(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    type(error_norms_scalar_t) :: error_norm
    real(rp) :: l2, h1, h1_s
    
    call error_norm%create(this%fe_space,1)
    l2   = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution,     l2_norm)
    h1_s = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution, h1_seminorm)
    h1   = error_norm%compute(this%poisson_analytical_functions%get_solution_function(), this%solution,     h1_norm)
    
    write(*,'(a20,e32.25)') 'l2_norm:'    , l2
    write(*,'(a20,e32.25)') 'h1_seminorm:', h1_s
    write(*,'(a20,e32.25)') 'h1_norm:'    , h1
    call error_norm%free()
    
  end subroutine check_solution
  
  subroutine write_solution(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(in) :: this
    type(output_handler_t)                   :: oh
    character(len=:), allocatable            :: path
    character(len=:), allocatable            :: prefix
    real(rp),allocatable :: cell_vector(:)
    integer(ip) :: N, P, pid, i
    class(cell_iterator_t), allocatable :: cell
    if(this%test_params%get_write_solution()) then
        path = this%test_params%get_dir_path_out()
        prefix = this%test_params%get_prefix()
        call oh%create()
        call oh%attach_fe_space(this%fe_space)
        call oh%add_fe_function(this%solution, 1, 'solution')
        call oh%add_fe_function(this%solution, 1, 'grad_solution', grad_diff_operator)
        call memalloc(this%triangulation%get_num_cells(),cell_vector,__FILE__,__LINE__)
        
        call this%triangulation%create_cell_iterator(cell)
        if (this%test_params%get_use_void_fes()) then
          do while( .not. cell%has_finished() )
            cell_vector(cell%get_gid()) = cell%get_set_id()
            call cell%next()
          end do
          call oh%add_cell_vector(cell_vector,'cell_set_ids')
        else
          N=this%triangulation%get_num_cells()
          P=6
          do pid=0, P-1
              i=0
              do while ( i < (N*(pid+1))/P - (N*pid)/P ) 
                cell_vector(cell%get_gid()) = pid 
                call cell%next()
                i=i+1
              end do
          end do
          call oh%add_cell_vector(cell_vector,'cell_set_ids')
        end if
        call this%triangulation%free_cell_iterator(cell)
        
        call oh%open(path, prefix)
        call oh%write()
        call oh%close()
        call oh%free()
        call memfree(cell_vector,__FILE__,__LINE__)
    endif
  end subroutine write_solution
  
  subroutine run_simulation(this) 
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    call this%free()
    call this%parse_command_line_parameters()
    call this%setup_triangulation()
    call this%setup_reference_fes()
    call this%setup_fe_space()
    call this%setup_system()
    call this%assemble_system()
    call this%setup_solver()
    call this%solve_system()
    call this%check_solution()
    call this%refine_and_coarsen()
    call this%write_solution()
    call this%free()
  end subroutine run_simulation
  
  subroutine free(this)
    implicit none
    class(test_poisson_error_estimator_driver_t), intent(inout) :: this
    integer(ip) :: i, istat
    call this%poisson_cG_error_estimator%free()
    call this%solution%free()
#ifdef ENABLE_MKL        
    call this%direct_solver%free()
#else
    call this%iterative_linear_solver%free()
#endif
    call this%fe_affine_operator%free()
    call this%fe_space%free()
    if ( allocated(this%reference_fes) ) then
      do i=1, size(this%reference_fes)
        call this%reference_fes(i)%p%free()
      end do
      deallocate(this%reference_fes, stat=istat)
      check(istat==0)
    end if
    call this%triangulation%free()
    call this%test_params%free()
  end subroutine free
  
end module test_poisson_error_estimator_driver_names
