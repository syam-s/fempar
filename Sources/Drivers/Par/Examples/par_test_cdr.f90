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
program par_test_cdr
  !----------------------------------------------------------
  ! Parallel partitioner test
  !----------------------------------------------------------
  use fem
  use par
  use cdr_names
  use cdr_stabilized_continuous_Galerkin_names 
  use mpi
  
  implicit none
#include "debug.i90" 
  ! Our data
  type(par_context)                       :: context
  type(par_environment)                   :: p_env
  type(par_mesh)                          :: p_mesh
  type(par_triangulation)                 :: p_trian
  type(par_matrix), target                :: p_mat
  type(par_vector), target                :: p_vec, p_unk
  class(base_operand) , pointer           :: x, y
  class(base_operator), pointer           :: A
  type(par_precond_dd_diagonal)           :: p_prec_dd_diag
  type(solver_control)     :: sctrl


  type(dof_distribution) , allocatable :: dof_dist(:)

  type(dof_handler)  :: dhand
  type(fem_space)    :: fspac

  type(par_graph), allocatable    :: dof_graph(:,:)
  integer(ip)                     :: gtype(1) = (/ csr_symm /)
  type(fem_conditions)  :: f_cond

  type(cdr_problem)               :: my_problem
  type(cdr_approximation), target :: my_approximation

  ! Arguments
  integer(ip)                   :: lunio
  character(len=256)            :: dir_path, dir_path_out
  character(len=256)            :: prefix
  character(len=:), allocatable :: name
  integer(ip)              :: i, j, ierror, iblock

  integer(ip), allocatable :: order(:,:), material(:), problem(:), which_approx(:)

  integer(ip), allocatable :: continuity(:,:)

  type(discrete_problem_pointer) :: approximations(1)

  call meminit

  ! Start parallel execution
  call par_context_create (context)

  ! Create parallel environment
  call par_environment_create( p_env, context )

  ! Read parameters from command-line
  call read_pars_cl ( dir_path, prefix, dir_path_out )

  ! Read mesh
  call par_mesh_read ( dir_path, prefix, p_env, p_mesh )

  ! Read boundary conditions
  call fem_conditions_compose_name(prefix,name) 
  call par_filename(context,name)
  lunio = io_open(trim(dir_path) // '/' // trim(name),status='old')
  call fem_conditions_read_file(lunio,p_mesh%f_mesh%npoin,f_cond)
  !f_cond%code = 0 !(dG)

  call par_mesh_to_triangulation (p_mesh, p_trian, f_cond)

  !write (*,*) '********** CREATE DOF HANDLER**************'
  call dhand%create( 1, 1, 1 )
  !call dof_handler_print ( dhand, 6 )


  call my_problem%create( p_trian%f_trian%num_dims )
  call my_approximation%create(my_problem)
  approximations(1)%p => my_approximation

  call dhand%set_problem( 1, my_approximation )
  ! ... for as many problems as we have

  call memalloc( p_trian%f_trian%num_elems, dhand%nvars_global, continuity, __FILE__, __LINE__)
  continuity = 1 !(dG)
  call memalloc( p_trian%f_trian%num_elems, dhand%nvars_global, order, __FILE__, __LINE__)
  order = 1
  call memalloc( p_trian%f_trian%num_elems, material, __FILE__, __LINE__)
  material = 1
  call memalloc( p_trian%f_trian%num_elems, problem, __FILE__, __LINE__)
  problem = 1
  
  call memalloc( p_trian%f_trian%num_elems, which_approx, __FILE__, __LINE__)
  which_approx = 1


  ! if ( context%iam > 0 ) then
  !    !pause
  !    do while ( 1 > 0)
  !       i = i + 1
  !    end do
  ! else
  !    write (*,*) 'Processor 0 not stopped'
  !    !i = 1
  !    !do while ( 1 > 0)
  !    !   i = i + 1
  !    !end do
  ! end if  


  ! Continuity
  ! write(*,*) 'Continuity', continuity
  call par_fem_space_create ( p_trian, dhand, fspac, problem, approximations, &
                              f_cond, continuity, order, material, &
                              which_approx, num_approximations=1, time_steps_to_store = 1, &
                              hierarchical_basis = logical(.false.,lg), &
                              & static_condensation = logical(.false.,lg), num_continuity = 1 )

  call update_strong_dirichlet_boundary_conditions( fspac )

  call par_create_distributed_dof_info ( dhand, p_trian, fspac, dof_dist, dof_graph, gtype )  

  if (p_trian%p_env%p_context%iam == 0 ) then
     !call triangulation_print ( 6, p_trian%f_trian, p_trian%num_elems + p_trian%num_ghosts)
     !call fem_space_print ( 6, fspac, p_trian%num_ghosts )
  end if


  call par_matrix_alloc ( csr_mat, symm_true, dof_graph(1,1), p_mat, positive_definite )

  call par_vector_alloc ( dof_dist(1), p_env, p_vec )
  p_vec%state = part_summed
  call par_vector_alloc ( dof_dist(1), p_env, p_unk )
  p_unk%state = full_summed

  call volume_integral( fspac, p_mat%f_matrix, p_vec%f_vector)

  call p_unk%init(1.0_rp)

  A => p_mat
  x => p_vec
  y => p_unk
  y = x - A*y
  write(*,*) 'XXX error norm XXX', y%nrm2()

  call par_precond_dd_diagonal_create ( p_mat, p_prec_dd_diag )
  call par_precond_dd_diagonal_ass_struct ( p_mat, p_prec_dd_diag )
  call par_precond_dd_diagonal_fill_val ( p_mat, p_prec_dd_diag )

  sctrl%method=cg
  sctrl%trace=1
  sctrl%itmax=800
  sctrl%dkrymax=800
  sctrl%stopc=res_res
  sctrl%orto=icgs
  sctrl%rtol=1.0e-06

  call p_unk%init(0.0_rp)

  ! AFM: I had to re-assign the state of punk as the expression
  ! y = x - A*y changed its state to part_summed!!! 
  p_unk%state = full_summed

  !call abstract_solve(p_mat,p_prec_dd_diag,p_vec,p_unk,sctrl,p_env)

  call par_precond_dd_diagonal_free ( p_prec_dd_diag, free_only_values )
  call par_precond_dd_diagonal_free ( p_prec_dd_diag, free_only_struct )
  call par_precond_dd_diagonal_free ( p_prec_dd_diag, free_clean )

  call par_matrix_free (p_mat)
  call par_vector_free (p_vec)
  call par_vector_free (p_unk)

  call memfree( continuity, __FILE__, __LINE__)
  call memfree( order, __FILE__, __LINE__)
  call memfree( material, __FILE__, __LINE__)
  call memfree( problem, __FILE__, __LINE__)
  call memfree( which_approx, __FILE__, __LINE__)

  do i = 1, dhand%nblocks
     do j = 1, dhand%nblocks
        call par_graph_free( dof_graph(i,j) )
     end do
  end do
  call memfree ( dof_graph, __FILE__, __LINE__ )

  do iblock=1, dhand%nblocks
     call dof_distribution_free(dof_dist(iblock))
  end do
  deallocate(dof_dist)

  call fem_space_free(fspac) 
  call my_problem%free
  call my_approximation%free
  call dof_handler_free (dhand)
  call par_triangulation_free(p_trian)
  call fem_conditions_free (f_cond)
  call par_mesh_free (p_mesh)
  call par_environment_free (p_env)
  call par_context_free ( context )

  ! call memstatus

contains
  subroutine read_pars_cl (dir_path, prefix, dir_path_out)
    implicit none
    character*(*), intent(out)   :: dir_path, prefix, dir_path_out
    character(len=256)           :: program_name
    character(len=256)           :: argument 
    integer                      :: numargs,iargc

    numargs = iargc()
    call getarg(0, program_name)
    if (.not. (numargs==3) ) then
       write (6,*) 'Usage: ', trim(program_name), ' dir_path prefix dir_path_out'
       stop
    end if

    call getarg(1, argument)
    dir_path = trim(argument)

    call getarg(2, argument)
    prefix = trim(argument)

    call getarg(3,argument)
    dir_path_out = trim(argument)

  end subroutine read_pars_cl

  subroutine update_strong_dirichlet_boundary_conditions( fspac )
    implicit none
    type(fem_space), intent(inout)    :: fspac
    
    integer(ip) :: ielem, iobje, ivar, inode, l_node

    do ielem = 1, fspac%g_trian%num_elems
       do iobje = 1,fspac%lelem(ielem)%p_geo_info%nobje
          do ivar=1, fspac%dof_handler%problems(problem(ielem))%p%nvars
             
             do inode = fspac%lelem(ielem)%nodes_object(ivar)%p%p(iobje), &
                  &     fspac%lelem(ielem)%nodes_object(ivar)%p%p(iobje+1)-1 
                l_node = fspac%lelem(ielem)%nodes_object(ivar)%p%l(inode)
                if ( fspac%lelem(ielem)%bc_code(ivar,iobje) /= 0 ) then
                   fspac%lelem(ielem)%unkno(l_node,ivar,1) = 1.0_rp
                end if
             end do
          end do
       end do
    end do
  end subroutine update_strong_dirichlet_boundary_conditions

end program par_test_cdr