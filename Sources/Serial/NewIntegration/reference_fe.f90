module reference_fe_names
  use allocatable_array_ip1_names
  use shape_values_names
  use types_names
  use list_types_names
  use memor_names
  implicit none
# include "debug.i90"

  private

  ! This module includes all the reference FE related machinery that is required
  ! to integrate FE schemes. It includes the following types:
  !
  ! * reference_fe_t: the basic reference_fe object, which is an abstract type
  ! * quad_lagrangian_reference_fe_t: one particular concrete version of the 
  !   reference fe_t
  ! * quadrature_t: Set of points and weights to perform numerical integration.
  !   It is created by the concrete reference_fe_t by providing the maximum order
  !   to be integrated exactly for zero order terms, e.g., mass matrix
  ! * interpolation_t: The value of the reference FE shape functions (firs and second
  !   order derivatives) on the quadrature points. It is generated by a concrete 
  !   reference_fe_t and a quadrature_t. It is computed in the concrete reference_fe_t
  ! * fe_map_t: It provides the mapping from a physical FE to the reference FE
  !   (jacobian, etc.)
  ! * volume_integrator_t: It aggregates all the aforementioned structures to be
  !   used in the FE element integration subroutine. In particular, one 
  !   reference_fe_t for the unknowns and one for the geometry (for non-isoparametric
  !   cases), one quadrature, and the corresponding interpolation. Further, it 
  !   includes the physical FE to the reference one in a fe_map_t and the
  !   composition of the FE map and the interpolation, to provide derivatives in the
  !   physical space

  type SB_quadrature_t
     private
     integer(ip)           :: &
          number_dimensions,    &
          number_integration_points                    ! Number of integration points
     real(rp), allocatable :: &
          coordinates(:,:),             &    ! Quadrature points position
          weight(:)                  ! Quadrature points weight
   contains
     procedure :: create => quadrature_create
     procedure :: free   => quadrature_free
     procedure :: print  => quadrature_print

     procedure :: get_number_dimensions => quadrature_get_number_dimensions
     procedure :: get_number_integration_points => quadrature_get_number_integration_points

     procedure :: get_weight => quadrature_get_weight
  end type SB_quadrature_t

  ! Types
  public :: SB_quadrature_t

  type face_quadrature_t
     private
     integer(ip)           :: number_dimensions                ! Space dimension of the element
     integer(ip)           :: number_integration_points_x_face ! Gauss points in each face
     integer(ip)           :: number_faces_x_element           ! #faces in each element
      
     real(rp), allocatable :: coordinates(:,:,:)               ! coordinates of the integration pnts
   contains
     ! Check sbm_face_quadrature for the definition of the subroutines
     procedure :: create => face_quadrature_create
     procedure :: free   => face_quadrature_free
     procedure :: print  => face_quadrature_print
  end type face_quadrature_t

  public :: face_quadrature_t

  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  type SB_interpolation_t
     private

     integer(ip)                ::  &
          number_dimensions,        &      
          number_shape_functions,   &      
          number_evaluation_points, &      
          number_entries_symmetric_tensor
     ! (usually integration points)

     real(rp), allocatable      ::  &
          shape_functions(:,:),     &   ! Shape functions
          shape_derivatives(:,:,:), &   ! Derivatives
          hessian(:,:,:)                ! Hessian       

   contains

     procedure :: create => interpolation_create
     procedure :: copy   => interpolation_copy
     procedure :: free   => interpolation_free
     procedure :: print  => interpolation_print

     !procedure :: get_number_dimensions => interpolation_get_number_dimensions
     !procedure :: get_number_shape_functions => interpolation_get_number_shape_functions
     !procedure :: get_number_evaluation_points => interpolation_get_number_evaluation_points
     !procedure :: get_number_entries_symmetric_tensor => interpolation_get_number_entries_symmetric_tensor

     !procedure :: get_shape_function => interpolation_get_shape_function
     procedure :: get_shape_derivative => interpolation_get_shape_derivative
     !procedure :: get_hessian  => interpolation_get_hessian

  end type SB_interpolation_t

  public :: SB_interpolation_t


  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  ! Abstract reference_fe
  type, abstract ::  reference_fe_t
     private
     character(:), allocatable :: &
          topology,               &    ! type of element, 'tet', 'quad', 'prism'...
          fe_type,                &    ! 'Lagrangian', 'RT', ...
          field_type

     integer(ip)              ::    &        
          number_dimensions,        &        ! ndime
          order,                    &        ! FE order
          field_components

     logical                  ::    &
          continuity                         ! CG/DG case (changes ndxob)

     integer(ip)              ::    &
          number_vefs,              &        ! Number of vefs
          number_nodes,             &        ! Number of nodes
          number_vefs_dimension(5)           ! Pointer to vef for each dimension

     ! Internal-use arrays of geometrical information
     type(allocatable_array_ip1_t)  :: orientation    ! Orientation of the vefs 
     type(list_t)   :: interior_nodes_vef !ndxob      ! array of interior nodes per vef
     type(list_t)   :: nodes_vef !ntxob               ! array of all nodes per vef
     type(list_t)   :: corners_vef !crxob             ! array of corners per vef
     type(list_t)   :: vefs_vef !obxob  ! array that list_ts all the vefs in an vef (idem ntxob for p = 2)

   contains

     ! TBPs
     ! Fill topology, fe_type, number_dimensions, order, continuity 
     procedure (create_interface), deferred :: create 
     ! SB.alert : To be done
     procedure :: free => reference_fe_free
     procedure :: print => reference_fe_print

     ! Set number_dimensions, order, continuity
     procedure :: set_common_data => reference_fe_set_common_data
     procedure :: set_topology => reference_fe_set_topology
     procedure :: set_fe_type => reference_fe_set_fe_type

     ! Getters
     procedure :: get_number_dimensions => reference_fe_get_number_dimensions
     procedure :: get_order => reference_fe_get_order
     procedure :: get_continuity => reference_fe_get_continuity
     procedure :: get_number_field_components => reference_fe_get_number_field_components
     !procedure :: get_topology
     !procedure :: get_fe_type

     procedure :: get_number_vefs => reference_fe_get_number_vefs
     procedure :: get_number_nodes => reference_fe_get_number_nodes
     procedure :: get_number_vefs_dimension => reference_fe_get_number_vefs_dimension
     procedure :: get_orientation => reference_fe_get_orientation
     procedure :: get_interior_nodes_vef  => reference_fe_get_interior_nodes_vef ! returns ndxob
     procedure :: get_nodes_vef  =>     reference_fe_get_nodes_vef ! returns ntxob
     procedure :: get_corners_vef  =>   reference_fe_get_corners_vef     ! returns crxob
     procedure :: get_vefs_vef   =>   reference_fe_get_vefs_vef     ! returns obxob

     ! Get only a particular node of the vef
     procedure :: get_node_vef => reference_fe_get_node_vef
     ! Idem interior
     procedure :: get_interior_node_vef => reference_fe_get_interior_node_vef
     procedure :: get_number_nodes_vef => reference_fe_get_number_nodes_vef
     procedure :: get_number_interior_nodes_vef => reference_fe_get_number_interior_nodes_vef

     ! This subroutine gives the reodering (o2n) of the nodes of an vef given an orientation 'o'
     ! and a delay 'r' wrt to a refence element sharing the same vef.
     procedure (permute_order_vef_interface), deferred :: permute_order_vef
     ! generic part of the subroutine above
     procedure :: permute_nodes_per_vef

     ! TBP to create an interpolation from a quadrature_t and reference_fe_t, 
     ! i.e., the value of the shape functions of the reference element on the quadrature points. 
     procedure (create_interpolation_interface), deferred :: create_interpolation 
     ! TBP to create a quadrature for a reference_fe_t
     procedure (create_quadrature_interface), deferred :: create_quadrature
     procedure ( create_face_quadrature_interface), deferred :: create_face_quadrature

     procedure(reference_fe_get_value_interface), deferred :: get_value
     procedure(reference_fe_get_gradient_interface), deferred :: get_gradient

     procedure(reference_fe_get_bc_code_interface), deferred :: get_bc_code


  end type reference_fe_t

  type p_reference_fe_t
     class(reference_fe_t), pointer :: p => NULL()      
  end type p_reference_fe_t

  abstract interface
     subroutine create_interface ( this, number_dimensions, order, field_type, continuity )
       import :: reference_fe_t, ip
       implicit none 
       class(reference_fe_t), intent(out) :: this 
       character(*), intent(in) :: field_type
       integer(ip), intent(in)  :: number_dimensions, order
       logical, optional, intent(in) :: continuity
     end subroutine create_interface
  end interface
  abstract interface
     subroutine create_interpolation_interface ( this, quadrature, interpolation, compute_hessian )
       import :: reference_fe_t, SB_interpolation_t, SB_quadrature_t
       implicit none 
       class(reference_fe_t), intent(in) :: this 
       class(SB_quadrature_t), intent(in) :: quadrature
       type(SB_interpolation_t), intent(out) :: interpolation
       logical, optional, intent(in) :: compute_hessian
     end subroutine create_interpolation_interface
  end interface
  abstract interface
     subroutine permute_order_vef_interface( this, o2n,p,o,r,nd )
       import :: reference_fe_t, ip
       implicit none
       class(reference_fe_t), intent(in) :: this 
       integer(ip), intent(in)    :: p,o,r,nd
       integer(ip), intent(inout) :: o2n(:)
     end subroutine permute_order_vef_interface
  end interface
  abstract interface
     subroutine create_quadrature_interface ( this, quadrature, max_order )
       import :: reference_fe_t, SB_quadrature_t, ip
       implicit none 
       class(reference_fe_t), intent(in) :: this        
       integer(ip), optional, intent(in) :: max_order
       class(SB_quadrature_t), intent(out) :: quadrature
     end subroutine create_quadrature_interface
  end interface
  abstract interface
     subroutine create_face_quadrature_interface ( this, face_quadrature, local_quadrature)
       import :: reference_fe_t, face_quadrature_t,  SB_quadrature_t 
       implicit none 
       class(reference_fe_t)   , intent(in)  :: this        
       class(face_quadrature_t), intent(out) :: face_quadrature
       class(SB_quadrature_t)  , intent(in)  :: local_quadrature
     end subroutine create_face_quadrature_interface
  end interface
  abstract interface
     subroutine reference_fe_get_value_interface( this, shp, int, node, gp )
       import :: reference_fe_t, SB_interpolation_t, rp, ip
       implicit none
       class(reference_fe_t), intent(in) :: this 
       type(SB_interpolation_t), intent(in) :: int 
       integer(ip), intent(in)  :: node, gp
       real(rp), intent(inout) :: shp(:,:)
     end subroutine reference_fe_get_value_interface
  end interface
  abstract interface
     subroutine reference_fe_get_gradient_interface( this, shg, int, node, gp )
       import :: reference_fe_t, SB_interpolation_t, rp, ip
       implicit none
       class(reference_fe_t), intent(in) :: this 
       type(SB_interpolation_t), intent(in) :: int 
       integer(ip), intent(in)  :: node, gp
       real(rp), intent(inout) :: shg(:,:)
     end subroutine reference_fe_get_gradient_interface
  end interface
  abstract interface
     function reference_fe_get_bc_code_interface( this, cond, node )
       import :: reference_fe_t, ip
       implicit none
       class(reference_fe_t), intent(in) :: this 
       integer(ip), intent(in) :: cond(:), node
       integer(ip) :: reference_fe_get_bc_code_interface
     end function reference_fe_get_bc_code_interface
  end interface


  public :: reference_fe_t, p_reference_fe_t

  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  type, extends(reference_fe_t) :: quad_lagrangian_reference_fe_t
  private
  integer(ip) :: number_nodes_scalar
  integer(ip), allocatable :: node_component_array(:,:)
contains 
  procedure :: create => quad_lagrangian_reference_fe_create
  procedure :: free   => quad_lagrangian_reference_fe_free
  procedure :: create_interpolation => quad_lagrangian_reference_fe_create_interpolation
  !procedure :: set_integration_rule
  procedure :: create_quadrature => quad_lagrangian_reference_fe_create_quadrature
  procedure :: create_face_quadrature => quad_lagrangian_reference_fe_create_face_quadrature
  procedure :: fill => quad_lagrangian_reference_fe_fill
  !procedure :: local_to_ijk_node     
  !procedure :: ijk_to_local_node     
  procedure :: permute_order_vef => quad_lagrangian_reference_fe_permute_order_vef
  procedure :: get_value => quad_lagrangian_reference_fe_get_value
  procedure :: get_gradient => quad_lagrangian_reference_fe_get_gradient
  procedure :: get_bc_code => quad_lagrangian_reference_fe_get_bc_code

end type quad_lagrangian_reference_fe_t

public :: quad_lagrangian_reference_fe_t


!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type fe_map_t
  private
  real(rp), allocatable  :: jacobian(:,:,:)     ! Map Jacobian         (ndime,ndime,nlocs)
  real(rp), allocatable  :: inv_jacobian(:,:,:) ! Map Jacobian inverse (ndime,ndime,nlocs)
  real(rp), allocatable  :: det_jacobian(:)     ! Map Jacobian det     (nlocs)
  real(rp), allocatable  :: d2sdx(:,:,:,:) ! 2nd derivatives (ndime,ndime,ndime,nlocs)
  real(rp), allocatable  :: coordinates_points(:,:)     ! Coordinates of evaluation points (ndime,nlocs)

contains

  procedure :: get_det_jacobian => fe_map_get_det_jacobian
  procedure :: free             => fe_map_free

end type fe_map_t


public :: fe_map_t


!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type SB_volume_integrator_t 
  private
  type(SB_quadrature_t) :: quadrature ! Quadrature rules for elements
  class(reference_fe_t), pointer :: reference_fe
  type(SB_interpolation_t) :: interpolation ! Unknown interpolation_t in the reference element domain
  class(reference_fe_t), pointer :: reference_fe_geometry
  type(SB_interpolation_t) :: interpolation_geometry ! Geometry interpolation_t in the reference element domain

  ! Working arrays
  type(SB_interpolation_t) :: interpolation_o_map ! Unknown interpolation_t in the physical element domain

  ! FE map
  type(fe_map_t) :: fe_map

  type(shape_values_t) :: shape_value_test, shape_gradient_test
  type(shape_values_t) :: shape_value_trial, shape_gradient_trial

contains

  procedure :: create => volume_integrator_create
  procedure :: free   => volume_integrator_free
  procedure :: print  => volume_integrator_print
  procedure :: update => volume_integrator_update
  procedure :: set_integration => volume_integrator_set_integration

  procedure :: get_reference_fe  => volume_integrator_get_reference_fe
  procedure :: get_quadrature    => volume_integrator_get_quadrature
  procedure :: get_interpolation => volume_integrator_get_interpolation

  procedure :: get_fe_map => volume_integrator_get_fe_map

  procedure :: compute_gradient_test => volume_integrator_compute_gradient_test
  procedure :: compute_value_test => volume_integrator_compute_value_test
  procedure :: get_gradients => volume_integrator_get_gradients
  procedure :: get_values => volume_integrator_get_values

  !procedure :: compute_gradient_trial => volume_integrator_compute_gradient_trial
  !procedure :: compute_value_trial => volume_integrator_compute_value_trial
  !procedure :: get_gradient_trial => volume_integrator_get_gradient_trial
  !procedure :: get_value_trial => volume_integrator_get_value_trial

end type SB_volume_integrator_t



type SB_p_volume_integrator_t
  type(SB_volume_integrator_t)          , pointer :: p => NULL() 
end type SB_p_volume_integrator_t

public :: SB_volume_integrator_t, SB_p_volume_integrator_t

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

contains

  ! Includes with all the TBP and supporting subroutines for the types above.
  ! In a future, we would like to use the submodule features of FORTRAN 2008.

#include "sbm_reference_fe.i90"

#include "sbm_face_quadrature.i90"

#include "sbm_quad_lagrangian_reference_fe.i90"

#include "sbm_quadrature.i90"

#include "sbm_interpolation.i90"

#include "sbm_volume_integrator.i90"

#include "sbm_quad_lagrangian_reference_face.i90"

end module reference_fe_names
