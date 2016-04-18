module command_line_parameters_names
  use serial_names
  use par_names
  implicit none
#include "debug.i90" 
  private
  
  ! Types
  type par_test_reference_fe_parameters_t
     ! Input problem location
     character(len=256) :: dir_path
     character(len=256) :: prefix
     
     ! Number of parts in which the problem was split
     integer(ip)                       :: nparts
     type(Type_Command_Line_Interface) :: cli
  contains
     procedure :: set_default_params => par_test_reference_fe_parameters_set_default_params
     procedure :: set_cli            => par_test_reference_fe_parameters_set_cli
     procedure :: parse              => par_test_reference_fe_parameters_parse
  end type par_test_reference_fe_parameters_t

  ! Types
  public :: par_test_reference_fe_parameters_t

contains
  !==================================================================================================
  subroutine par_test_reference_fe_parameters_set_default_params(params)
    implicit none
    class(par_test_reference_fe_parameters_t), intent(inout) :: params
    params%dir_path = ''
    params%prefix = ''
  end subroutine par_test_reference_fe_parameters_set_default_params

  !==================================================================================================
  subroutine par_test_reference_fe_parameters_set_cli(params)
    implicit none
    class(par_test_reference_fe_parameters_t), intent(inout) :: params
    integer(ip) :: error
    
    ! Initialize Command Line Interface
    call params%cli%init(progname    = 'par_test_reference_fe', &
         &               version     = '',                               &
         &               authors     = '',                               &
         &               license     = '',                               &
         &               description = "FEMPAR parallel test driver", &
         &               examples    = ['par_test_reference_fe -h'] )

    ! Set Command Line Arguments
    call params%cli%add(switch='--dir-path',switch_ab='-dir-path',help='Absolute or relative PATH to the partitioned&
                       & problem. Must end with /',required=.true., act='store', error=error)
    check(error==0)

    call params%cli%add(switch='--prefix',switch_ab='-prefix',help='Prefix for all input files (mesh, conditions, etc.).& 
                       & E.g., if these files were generated from square.gid GiD project, then --prefix square.',& 
                       & required=.true., act='store', error=error)
    check(error==0)

    call params%cli%add(switch='--nparts',switch_ab='-nparts',help='Number of parts in which the problem was split.',& 
                       & required=.true., act='store', error=error)
    check(error==0)
  end subroutine par_test_reference_fe_parameters_set_cli

  !==================================================================================================
  subroutine par_test_reference_fe_parameters_parse(params)
    implicit none
    class(par_test_reference_fe_parameters_t), intent(inout) :: params
    integer(ip)                                                        :: error
    character(len=256)                                                 :: aux_string
    logical                                                            :: aux_logical

    call params%cli%parse(error=error)
    check(error==0)

    call params%cli%get(switch='-dir-path',val=params%dir_path,error=error); check(error==0)
    call params%cli%get(switch='-prefix',val=params%prefix,error=error); check(error==0)
    call params%cli%get(switch='-nparts',val=params%nparts,error=error); check(error==0)
  end subroutine par_test_reference_fe_parameters_parse
end module command_line_parameters_names

module poisson_discrete_integration_names
  use serial_names
  
  implicit none
# include "debug.i90"
  private
  type, extends(discrete_integration_t) :: poisson_discrete_integration_t
     integer(ip) :: viscosity 
   contains
     procedure :: integrate
  end type poisson_discrete_integration_t
  
  public :: poisson_discrete_integration_t
  
contains
  
  subroutine integrate ( this, fe_space, assembler )
    implicit none
    class(poisson_discrete_integration_t), intent(in)    :: this
    class(serial_fe_space_t)          , intent(inout) :: fe_space
    class(assembler_t)                , intent(inout) :: assembler

    type(finite_element_t), pointer :: fe
    type(volume_integrator_t), pointer :: vol_int
    real(rp), allocatable :: elmat(:,:), elvec(:)
    type(fe_map_t), pointer :: fe_map
    type(quadrature_t), pointer :: quad

    integer(ip)  :: igaus,inode,jnode,ngaus
    real(rp)     :: factor

    type(vector_field_t) :: grad_test, grad_trial

    integer(ip) :: number_fe_spaces

    integer(ip), pointer :: field_blocks(:)
    logical, pointer :: field_coupling(:,:)

    integer(ip) :: ielem, iapprox, number_nodes
    type(i1p_t), pointer :: elem2dof(:)
    integer(ip), allocatable :: number_nodes_per_field(:)  

    number_fe_spaces = fe_space%get_number_fe_spaces()
    field_blocks => fe_space%get_field_blocks()
    field_coupling => fe_space%get_field_coupling()

    fe => fe_space%get_finite_element(1)
    number_nodes = fe%get_number_nodes()
    call memalloc ( number_nodes, number_nodes, elmat, __FILE__, __LINE__ )
    call memalloc ( number_nodes, elvec, __FILE__, __LINE__ )
    call memalloc ( number_fe_spaces, number_nodes_per_field, __FILE__, __LINE__ )
    call fe%get_number_nodes_per_field( number_nodes_per_field )

    call fe_space%initialize_integration()
    
    quad => fe%get_quadrature()
    ngaus = quad%get_number_quadrature_points()
    do ielem = 1, fe_space%get_number_elements()
       elmat = 0.0_rp
       elvec = 0.0_rp

       fe => fe_space%get_finite_element(ielem)
       call fe%update_integration()
       
       fe_map   => fe%get_fe_map()
       vol_int  => fe%get_volume_integrator(1)
       elem2dof => fe%get_elem2dof()

       do igaus = 1,ngaus
          factor = fe_map%get_det_jacobian(igaus) * quad%get_weight(igaus)
          do inode = 1, number_nodes
             call vol_int%get_gradient(inode,igaus,grad_trial)
             do jnode = 1, number_nodes
                call vol_int%get_gradient(jnode,igaus,grad_test)
                elmat(inode,jnode) = elmat(inode,jnode) + factor * grad_test * grad_trial
             end do
          end do
       end do
       !write (*,*) 'XXXXXXXXX ELMAT XXXXXXXXX'
       !write (*,*) elmat
       
       ! Apply boundary conditions
       call fe%impose_strong_dirichlet_bcs( elmat, elvec )
       call assembler%assembly( number_fe_spaces, number_nodes_per_field, elem2dof, field_blocks,  field_coupling, elmat, elvec )
    end do
    call memfree ( number_nodes_per_field, __FILE__, __LINE__ )
    call memfree ( elmat, __FILE__, __LINE__ )
    call memfree ( elvec, __FILE__, __LINE__ )
  end subroutine integrate
end module poisson_discrete_integration_names

module vector_laplacian_composite_discrete_integration_names
use serial_names

implicit none
# include "debug.i90"
private
type, extends(discrete_integration_t) :: vector_laplacian_composite_discrete_integration_t
integer(ip) :: viscosity 
contains
procedure :: integrate
end type vector_laplacian_composite_discrete_integration_t

public :: vector_laplacian_composite_discrete_integration_t

contains
  subroutine integrate ( this, fe_space, assembler )
    implicit none
    class(vector_laplacian_composite_discrete_integration_t), intent(in)    :: this
    class(serial_fe_space_t)                   , intent(inout) :: fe_space
    class(assembler_t)                         , intent(inout) :: assembler

    type(finite_element_t), pointer :: fe
    type(volume_integrator_t), pointer :: vol_int_first_fe, vol_int_second_fe
    real(rp), allocatable :: elmat(:,:), elvec(:)
    type(fe_map_t), pointer :: fe_map
    type(quadrature_t), pointer :: quad
    integer(ip), allocatable :: number_nodes_per_field(:)

    integer(ip)  :: igaus,inode,jnode,ioffset,joffset,ngaus
    real(rp) :: factor

    type(vector_field_t) :: grad_test_scalar, grad_trial_scalar
    type(tensor_field_t) :: grad_test_vector, grad_trial_vector
    
    integer(ip) :: i, number_fe_spaces

    integer(ip), pointer :: field_blocks(:)
    logical, pointer :: field_coupling(:,:)

    integer(ip) :: ielem, number_nodes
    type(i1p_t), pointer :: elem2dof(:)

    number_fe_spaces = fe_space%get_number_fe_spaces()
    field_blocks => fe_space%get_field_blocks()
    field_coupling => fe_space%get_field_coupling()

    fe => fe_space%get_finite_element(1)
    number_nodes = fe%get_number_nodes()
    call memalloc ( number_nodes, number_nodes, elmat, __FILE__, __LINE__ )
    call memalloc ( number_nodes, elvec, __FILE__, __LINE__ )
    call memalloc ( number_fe_spaces, number_nodes_per_field, __FILE__, __LINE__ )
    call fe%get_number_nodes_per_field( number_nodes_per_field )
    
    call fe_space%initialize_integration()
    
    quad  => fe%get_quadrature()
    ngaus = quad%get_number_quadrature_points()
    do ielem = 1, fe_space%get_number_elements()
       elmat = 0.0_rp
       elvec = 0.0_rp

       fe => fe_space%get_finite_element(ielem)
       call fe%update_integration()
       
       fe_map            => fe%get_fe_map()
       vol_int_first_fe  => fe%get_volume_integrator(1)
       vol_int_second_fe => fe%get_volume_integrator(2)
       elem2dof          => fe%get_elem2dof()

       do igaus = 1,ngaus
          factor = fe_map%get_det_jacobian(igaus) * quad%get_weight(igaus)
          do inode = 1, number_nodes_per_field(1)
             call vol_int_first_fe%get_gradient(inode,igaus,grad_trial_scalar)
             do jnode = 1, number_nodes_per_field(1)
                call vol_int_first_fe%get_gradient(jnode,igaus,grad_test_scalar)
                elmat(inode,jnode) = elmat(inode,jnode) + factor * grad_test_scalar * grad_trial_scalar
             end do
          end do

          do inode = 1, number_nodes_per_field(2)
             ioffset = number_nodes_per_field(1)+inode
             call vol_int_second_fe%get_gradient(inode,igaus,grad_trial_scalar)
             ! write(*,*) inode, grad_trial_vector%value
             do jnode = 1, number_nodes_per_field(2)
                joffset = number_nodes_per_field(1)+jnode
                call vol_int_second_fe%get_gradient(jnode,igaus,grad_test_scalar)
                elmat(ioffset,joffset) = elmat(ioffset,joffset) + factor * grad_test_scalar * grad_trial_scalar
             end do
          end do
       end do
       call fe%impose_strong_dirichlet_bcs( elmat, elvec )
       call assembler%assembly( number_fe_spaces, number_nodes_per_field, elem2dof, field_blocks,  field_coupling, elmat, elvec )      
    end do
    call memfree ( number_nodes_per_field, __FILE__, __LINE__ )
    call memfree ( elmat, __FILE__, __LINE__ )
    call memfree ( elvec, __FILE__, __LINE__ )
  end subroutine integrate

end module vector_laplacian_composite_discrete_integration_names


program par_test_reference_fe
  !----------------------------------------------------------
  ! Parallel partitioner test
  !----------------------------------------------------------
  use serial_names
  use par_names
  use command_line_parameters_names
  use poisson_discrete_integration_names
  use vector_laplacian_composite_discrete_integration_names


  implicit none
#include "debug.i90" 

  ! Our data
  type(par_context_t)                             :: w_context, p_context, q_context, b_context
  type(par_environment_t)                         :: par_env
  type(par_mesh_t)                                :: par_mesh
  type(par_conditions_t)                          :: par_conditions
  type(par_triangulation_t)                       :: par_triangulation
  type(par_fe_space_t)                            :: par_fe_space
  type(p_reference_fe_t)                          :: reference_fe_array_one(2)
  type(fe_affine_operator_t)                      :: fe_affine_operator
  type(poisson_discrete_integration_t)            :: poisson_integration
  type(vector_laplacian_composite_discrete_integration_t) :: vector_laplacian_integration
  type(iterative_linear_solver_t)                 :: iterative_linear_solver
  type(fe_function_t)                             :: fe_function
  class(vector_t), pointer                        :: dof_values

  

  integer(ip)              :: num_levels
  integer(ip), allocatable :: id_parts(:), num_parts(:)
  
  type(par_test_reference_fe_parameters_t) :: test_params

  call fempar_init()

  ! Start parallel execution
  call par_context_create (w_context)

  call test_params%set_default_params()
  call test_params%set_cli()
  call test_params%parse()

  ! This test only works with two levels.
  num_levels = 2
  call memalloc(num_levels, id_parts , __FILE__, __LINE__)
  call memalloc(num_levels, num_parts, __FILE__, __LINE__)

  num_parts = (/test_params%nparts, 1/)
  id_parts = (/w_context%iam+1, 1/)


  ! Create p_context and q_context splitting w_context
  if(w_context%iam < num_parts(1)) then
     call par_context_create ( 1, p_context, q_context, w_context )
  else
     call par_context_create ( 2, q_context, p_context, w_context )
  end if
  assert ( (p_context%iam >=0 .and. q_context%iam < 0) .or. (p_context%iam < 0 .and. q_context%iam >= 0))
  
  ! Create b_context as an intercommunicator among p_context <=> q_context 
  call par_context_create ( w_context, p_context, q_context, b_context )

  ! Create parallel environment
  call par_environment_create( par_env,& 
                               w_context,& 
                               p_context,& 
                               q_context,&
                               b_context,&
                               num_levels,&
                               id_parts, & 
                               num_parts )

  ! Read mesh
  call par_mesh_read ( test_params%dir_path, test_params%prefix, par_env, par_mesh )

  ! Read boundary conditions
  call par_conditions_read(test_params%dir_path, test_params%prefix, par_mesh%f_mesh%npoin, par_env, par_conditions)

  ! Generate triangulation
  call par_mesh_to_triangulation (par_mesh, par_triangulation, par_conditions)
  
  ! Simple case
  reference_fe_array_one(1) =  make_reference_fe ( topology = topology_quad, &
                                                   fe_type = fe_type_lagrangian, &
                                                   number_dimensions = 2, &
                                                   order = 1, &
                                                   field_type = field_type_scalar, &
                                                   continuity = .true., &
                                                   enable_face_integration = .true. )
  
    reference_fe_array_one(2) =  make_reference_fe ( topology = topology_quad, &
                                                   fe_type = fe_type_lagrangian, &
                                                   number_dimensions = 2, &
                                                   order = -1, &
                                                   field_type = field_type_scalar, &
                                                   continuity = .true., &
                                                   enable_face_integration = .true. )
  
  !call reference_fe_array_one(1)%p%print()
  
  call par_fe_space%create( par_triangulation = par_triangulation, &
                            par_boundary_conditions = par_conditions, &
                            reference_fe_phy = reference_fe_array_one ) 

  call par_fe_space%update_bc_value (scalar_function=constant_scalar_function_t(1.0_rp), &
                                     bc_code = 1, &
                                     fe_space_component = 1 )
  
    call par_fe_space%update_bc_value (scalar_function=constant_scalar_function_t(1.0_rp), &
                                     bc_code = 1, &
                                     fe_space_component = 2 )
  
  call par_fe_space%fill_dof_info()
  call par_fe_space%print()
    
  call fe_affine_operator%create (sparse_matrix_storage_format='CSR', &
                                  diagonal_blocks_symmetric_storage=(/.true./), &
                                  diagonal_blocks_symmetric=(/.true./), &
                                  diagonal_blocks_sign=(/SPARSE_MATRIX_SIGN_POSITIVE_DEFINITE/), &
                                  environment=par_env, &
                                  fe_space=par_fe_space, &
                                  discrete_integration=vector_laplacian_integration )

  call fe_affine_operator%symbolic_setup()
  call fe_affine_operator%numerical_setup()
    
  
  call par_fe_space%create_global_fe_function(fe_function)
  
  
  ! Create iterative linear solver, set operators and solve linear system
  call iterative_linear_solver%create(par_env)
  call iterative_linear_solver%set_type_from_string(cg_name)
  call iterative_linear_solver%set_operators(fe_affine_operator, .identity. fe_affine_operator)
  dof_values => fe_function%get_dof_values()
  call iterative_linear_solver%solve(fe_affine_operator%get_translation(),dof_values)
  call iterative_linear_solver%free() 
  
  !call p_fe_space%par_fe_space_print()
  
  call fe_function%free()
  call fe_affine_operator%free()
  call par_fe_space%free()
  call reference_fe_array_one(1)%free()
  call reference_fe_array_one(2)%free()

  
  call par_triangulation_free(par_triangulation)
  call par_conditions_free (par_conditions)
  call par_mesh_free (par_mesh)

  call memfree(id_parts , __FILE__, __LINE__)
  call memfree(num_parts, __FILE__, __LINE__)

  call par_environment_free (par_env)
  call par_context_free ( b_context, .false. )
  call par_context_free ( p_context, .false. )
  call par_context_free ( q_context, .false. )
  call par_context_free ( w_context )

  call fempar_finalize()

end program par_test_reference_fe
