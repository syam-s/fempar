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
module command_line_parameters_names
  use types_names
  use Data_Type_Command_Line_Interface
# include "debug.i90"

  implicit none
  private

  type test_cdr_params_t
     character(len=:), allocatable :: default_dir_path
     character(len=:), allocatable :: default_prefix
     character(len=:), allocatable :: default_dir_path_out

     character(len=:), allocatable :: default_kfl_conv 
     character(len=:), allocatable :: default_kfl_tder 
     character(len=:), allocatable :: default_kfl_react 
     character(len=:), allocatable :: default_react
     character(len=:), allocatable :: default_diffu 
     character(len=:), allocatable :: default_space_solution_flag 
     character(len=:), allocatable :: default_tempo_solution_flag 

     character(len=:), allocatable :: default_kfl_thet 
     character(len=:), allocatable :: default_kfl_stab
     character(len=:), allocatable :: default_kfl_proj 
     character(len=:), allocatable :: default_k1tau   
     character(len=:), allocatable :: default_k2tau   
     character(len=:), allocatable :: default_dtinv 
     character(len=:), allocatable :: default_ctime 
     character(len=:), allocatable :: default_tdimv 
     character(len=:), allocatable :: default_nvars

     character(len=:), allocatable :: default_continuity
     character(len=:), allocatable :: default_enable_face_integration
     character(len=:), allocatable :: default_order
     
  end type test_cdr_params_t

  ! Types
  public :: test_cdr_params_t

  ! Functions
  public :: set_default_params, cli_add_params, set_default_params_analytical

contains

  subroutine set_default_params(params)
    implicit none
    type(test_cdr_params_t), intent(inout) :: params

    ! IO parameters
    params%default_dir_path     = 'data'
    params%default_prefix       = 'square_4x4'
    params%default_dir_path_out = 'output'

    ! Problem parameters
    params%default_kfl_conv            = '0' ! Enabling advection
    params%default_kfl_tder            = '0' ! Time derivative not computed 
    params%default_kfl_react           = '0' ! Non analytical reaction
    params%default_react               = '0.0'  ! Reaction
    params%default_diffu               = '1.0'  ! Diffusion
    params%default_space_solution_flag = '3'
    params%default_tempo_solution_flag = '0'

    ! Solver parameter
    params%default_kfl_thet = '0'   ! Theta-method time integration (BE=0, CN=0)
    params%default_kfl_stab = '0'   ! Stabilization of convective term (0: Off, 2: OSS)
    params%default_kfl_proj = '0'   ! Projections weighted with tau's (On=1, Off=0)
    params%default_k1tau    = '4.0' ! C1 constant on stabilization parameter
    params%default_k2tau    = '2.0' ! C2 constant on stabilization parameter
    params%default_dtinv    = '1.0' ! Inverse of time step
    params%default_ctime    = '0.0' ! Current time
    params%default_tdimv    = '2'   ! Number of temporal steps stored
    params%default_nvars    = '1'

    ! FE Space parameters
    params%default_continuity              = '1'
    params%default_enable_face_integration = '.false.'
    params%default_order                   = '1'
  end subroutine set_default_params
  !==================================================================================================

  subroutine cli_add_params(cli,params,group)
    implicit none
    type(Type_Command_Line_Interface)            , intent(inout) :: cli
    type(test_cdr_params_t)                      , intent(in)    :: params
    character(*)                                 , intent(in)    :: group
    ! Locals
    integer(ip) :: error

    ! Set Command Line Arguments
    ! IO parameters
    call cli%add(group=trim(group),switch='--dir_path',switch_ab='-d',                              &
         &       help='Directory of the source files',required=.false., act='store',                &
         &       def=trim(params%default_dir_path),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--prefix',switch_ab='-pr',help='Name of the GiD files',  &
         &       required=.false.,act='store',def=trim(params%default_prefix),error=error) 
    check(error==0)
    call cli%add(group=trim(group),switch='--dir_path_out',switch_ab='-out',help='Output Directory',&
         &       required=.false.,act='store',def=trim(params%default_dir_path_out),error=error)
    check(error==0)

    ! Problem parameters
    call cli%add(group=trim(group),switch='--kfl_conv',switch_ab='-kconv',help='Convection flag',   &
         &       required=.false.,act='store',def=trim(params%default_kfl_conv),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--kfl_react',switch_ab='-kreac',help='Reaction flag',    &
         &       required=.false.,act='store',def=trim(params%default_kfl_react),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--kfl_tder',switch_ab='-ktd',                            &
         &       help='Temporal derivative computation flag',required=.false.,act='store',          &
         &       def=trim(params%default_kfl_tder),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--react',switch_ab='-reac',help='Constant Reaction Value'&
         &       ,required=.false.,act='store',def=trim(params%default_react),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--diffu',switch_ab='-diff',                              &
         &       help='Constant Diffusion Value',required=.false.,act='store',                      &
         &       def=trim(params%default_diffu),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--space_solution_flag',switch_ab='-ssol',                &
         &       help='Space analytical solution',required=.false.,act='store',nargs='*',           &
         &       def=trim(params%default_space_solution_flag),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--tempo_solution_flag',switch_ab='-tsol',                &
         &       help='Temporal analytical solution',required=.false.,act='store',nargs='*',        &
         &       def=trim(params%default_tempo_solution_flag),error=error)
    check(error==0)

    ! Solver parameters
    call cli%add(group=trim(group),switch='--kfl_thet',switch_ab='-ktht',help='Theta method',       &
         &       required=.false.,act='store',def=trim(params%default_kfl_thet),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--kfl_stab',switch_ab='-kst',help='Stabilization flag',  &
         &       required=.false.,act='store',def=trim(params%default_kfl_stab),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--kfl_proj',switch_ab='-kpr',                            &
         &       help='Projections weighted with tau flag',required=.false.,act='store',            &
         &       def=trim(params%default_kfl_proj),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--k1tau',switch_ab='-k1t',help='Tau 1',                  &
         &       required=.false.,act='store',def=trim(params%default_k1tau),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--k2tau',switch_ab='-k2t',help='Tau 2',                  &
         &       required=.false.,act='store',def=trim(params%default_k2tau),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--dtinv',switch_ab='-tinv',help='Inverse of time step',  &
         &       required=.false.,act='store',def=trim(params%default_dtinv),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--ctime',switch_ab='-ct',help='Current time',            &
         &       required=.false.,act='store',def=trim(params%default_ctime),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--tdimv',switch_ab='-tss',                               &
         &       help='Number of temporal steps stored',required=.false.,act='store',               &
         &       def=trim(params%default_tdimv),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--nvars',switch_ab='-nv',                                &
         &       help='Number of variables of the problem',required=.false.,act='store',            &
         &       def=trim(params%default_nvars),error=error)
    check(error==0)

    ! FE Space parameters 
    call cli%add(group=trim(group),switch='--continuity',switch_ab='-cg',                           &
         &       help='Flag for the continuity of the FE Space',required=.false.,act='store',       &
         &       def=trim(params%default_continuity),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--face_integ',switch_ab='-fi',                           &
         &       help='Allow face integration',required=.false.,act='store',                        &
         &       def=trim(params%default_enable_face_integration),error=error)
    check(error==0)
    call cli%add(group=trim(group),switch='--order',switch_ab='-p',                                 &
         &       help='Initial order of the approximation',required=.false.,act='store',            &
         &       def=trim(params%default_order),error=error)
    check(error==0)
  end subroutine cli_add_params
  !==================================================================================================

  subroutine set_default_params_analytical(params)
    implicit none
    type(test_cdr_params_t), intent(inout) :: params

    ! Names
    params%default_kfl_conv            = '0'    ! Enabling advection
    params%default_kfl_tder            = '0'    ! Time derivative not computed 
    params%default_kfl_react           = '0'    ! Non analytical reaction
    params%default_react               = '0.0'  ! Reaction
    params%default_diffu               = '1.0'  ! Diffusion
    params%default_space_solution_flag = '4'
    params%default_tempo_solution_flag = '0'

  end subroutine set_default_params_analytical

end module command_line_parameters_names

!****************************************************************************************************
!****************************************************************************************************

program test_reference_fe
  use serial_names
  use Data_Type_Command_Line_Interface
  use command_line_parameters_names
  ! SB
  !use reference_face_names
  use reference_fe_names
  use reference_fe_factory_names
  use serial_fe_space_names
  use discrete_integration_names
  use stokes_discrete_integration_names 
  use maxwell_discrete_integration_names
  use fe_affine_operator_names
  implicit none
#include "debug.i90"

  ! Our data
  type(mesh_t)                          :: f_mesh
  type(triangulation_t)                 :: f_trian
  type(conditions_t)                    :: f_cond
  integer(ip)                           :: num_approximations
  class(matrix_t)             , pointer :: matrix
  class(array_t)              , pointer :: array
  class(vector_t) , allocatable, target :: vector, initial_solution
  class(vector_t) , pointer :: rhs
 

  type(linear_solver_t)                           :: linear_solver
  type(vector_space_t)    , pointer               :: fe_affine_operator_range_vector_space
  type(serial_environment_t)         :: senv

  ! Arguments
  character(len=256)       :: dir_path, dir_path_out
  character(len=256)       :: prefix, filename
  integer(ip)              :: i, j, vars_prob(1) = 1, ierror, iblock
  integer(ip)              :: space_solution_flag(1), tempo_solution_flag(1)

  integer(ip), allocatable :: order(:,:), material(:), problem(:)

  integer(ip), allocatable :: continuity(:,:)
  logical    , allocatable :: enable_face_integration(:,:)

  logical                  :: diagonal_blocks_symmetric_storage(1)
  logical                  :: diagonal_blocks_symmetric(1)
  integer(ip)              :: diagonal_blocks_sign(1)

  integer(ip) :: lunio, istat

  type(Type_Command_Line_Interface):: cli 
  character(len=:), allocatable :: group

  ! SB
  type(serial_fe_space_t)            :: fe_space
  type(stokes_discrete_integration_t)   :: stokes_integration 
  type(maxwell_discrete_integration_t)  :: maxwell_integration
  type(fe_affine_operator_t)         :: fe_affine_operator
  type(p_reference_fe_t)                :: composite_reference_array(2)

  integer(ip), allocatable :: nnodesfield(:)
  integer(ip) :: problem_id
  real(rp)    :: u_norm 

  call meminit

  ! Read IO parameters
  call read_flap_cli_test_maxwell(cli)
  call cli%parse(error=istat)
  if(cli%run_command('analytical')) then
     group = 'analytical'
  else
     group = 'analytical'
  end if
  call cli%get(group=trim(group),switch='-d',val=dir_path,error=istat); check(istat==0)
  call cli%get(group=trim(group),switch='-pr',val=prefix,error=istat); check(istat==0)
  call cli%get(group=trim(group),switch='-out',val=dir_path_out,error=istat); check(istat==0)

  ! Read mesh
  call mesh_read (dir_path, prefix, f_mesh, permute_c2z=.true.)

  ! Read conditions 
  call conditions_read (dir_path, prefix, f_mesh%npoin, f_cond)

  ! Impose Analytical Dirichlet conditions 
  call analytical_update(f_mesh, f_cond, u_norm)

  ! Construct triangulation
  call mesh_to_triangulation ( f_mesh, f_trian, gcond = f_cond )

  ! Composite case (u,p)
     composite_reference_array(1) = make_reference_fe ( topology = topology_quad, &
                                                     fe_type = fe_type_lagrangian, &
                                                     number_dimensions = 2, &
                                                     order = 1, &
                                                     field_type = field_type_vector, &
                                                     continuity = .true. )
     
     composite_reference_array(2) = make_reference_fe ( topology = topology_quad, &
                                                     fe_type = fe_type_lagrangian, &
                                                     number_dimensions = 2, &
                                                     order = 1, & 
                                                     field_type = field_type_scalar, &
                                                     continuity = .true. )
 
     call fe_space%create( triangulation = f_trian, &
                           boundary_conditions = f_cond, &
                           reference_fe_phy = composite_reference_array, &
                           field_blocks = (/1,2/), &
                           field_coupling = reshape((/.true.,.true.,.true.,.true./),(/2,2/)) )   

   call fe_space%fill_dof_info() 
 
   call fe_space%print()
 
   call fe_affine_operator%create ( 'CSR', &
                                    (/.true.,.true./), &
                                    (/.true.,.true./), &
                                    (/SPARSE_MATRIX_SIGN_POSITIVE_DEFINITE,SPARSE_MATRIX_SIGN_POSITIVE_DEFINITE/),&
                                    f_trian, &
                                    fe_space, &
                                    maxwell_integration )
  
  call fe_affine_operator%symbolic_setup()
  call fe_affine_operator%numerical_setup()
  
  matrix => fe_affine_operator%get_matrix()
  rhs    => fe_affine_operator%get_array()
 
  select type(matrix)
    class is (sparse_matrix_t)
      call matrix%print_matrix_market(6)
  end select
  
  fe_affine_operator_range_vector_space => fe_affine_operator%get_range_vector_space()
  call fe_affine_operator_range_vector_space%create_vector(vector)

  ! Create linear solver, set operators and solve linear system
    call linear_solver%create(senv)
    call linear_solver%set_type_and_parameters_from_pl()
    call linear_solver%set_operators(fe_affine_operator, .identity. fe_affine_operator)
    call linear_solver%solve(vector)
  !  call linear_solver%print_convergence_history('csic')
    call linear_solver%free() 

   select type(vector)
     class is(serial_block_array_t)
     write(*,*) ' --------------------------------------------------------- '
     write(*,*) 'Magnetic field error norm: ', abs (vector%blocks(1)%nrm2()-u_norm)
     write(*,*) 'p-multiplier error norm: '  , vector%blocks(2)%nrm2()
     write(*,*) ' --------------------------------------------------------- '
    ! call vector%print(6)
     class default
     check(.false.) 
  end select 
 ! ============================================================================================

  call vector%free()
  deallocate(vector)
  call fe_affine_operator%free()
  call fe_space%free()
  call triangulation_free(f_trian)
  call conditions_free ( f_cond )
  call mesh_free (f_mesh)

   call memstatus 
contains
  !==================================================================================================

  subroutine read_flap_cli_test_maxwell(cli)
    implicit none
    type(Type_Command_Line_Interface), intent(out) :: cli
    ! Locals
    type(test_cdr_params_t) :: analytical_params

    ! Initialize Command Line Interface
    call cli%init(progname    = 'test_maxwell',                                                         &
         &        version     = '',                                                                 &
         &        authors     = '',                                                                 & 
         &        license     = '',                                                                 &
         &        description =                                                                     &
         &    'Serial FEMPAR driver to solve the steady maxwell time-harmonic equation .',   &
         &        examples    = ['test_maxwell -h            ', 'test_maxwell analytical -h ' ])

    ! Set Command Line Arguments Groups, i.e. commands
    call cli%add_group(group='analytical',description='Solve a problem with an analytical solution')

    ! Set Command Line Arguments for each group
    call set_default_params(analytical_params)
    call set_default_params_analytical(analytical_params)
    call cli_add_params(cli,analytical_params,'analytical')

  end subroutine read_flap_cli_test_maxwell
  !==================================================================================================

! Imposing Dirichlet boundary conditions, dirty! 
  subroutine analytical_update(mesh, cond, u_norm) 
    implicit none 
   type(mesh_t) , intent(in)          :: mesh 
   type(conditions_t) , intent(inout) :: cond
   real(rp)           , intent(out)   :: u_norm 

   ! Locals 
   real(ip) :: ipoin, idime, x, y, z

u_norm = 0.0_rp
 do ipoin = 1,mesh%npoin

  x = mesh%coord(1,ipoin)
  y = mesh%coord(2,ipoin)
if (mesh%ndime == 3) z = mesh%coord(3,ipoin) 
  
if (cond%code(1,ipoin) == 1 ) then  ! u analytical = [ y(L-y) , x(L-x) ] 
  f_cond%valu(1,ipoin) = y*(1-y) 
  f_cond%valu(2,ipoin) = x*(1-x) 
if (mesh%ndime == 3) f_cond%valu(3,ipoin) = sin(2*pi*z)

else 
u_norm = u_norm + x*x*(1-x)*(1-x) + y*y*(1-y)*(1-y) 
 end if

 end do
u_norm = sqrt(u_norm)

  end subroutine analytical_update

end program test_reference_fe
