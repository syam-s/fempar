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
# include "debug.i90"
module fem_element_names
  ! Modules
  use types
  use memor
  use array_names
  use integration_tools_names
  !use face_integration_names
  use fem_space_types
  !use dof_handler_names
  use migratory_element_names
  !use fem_conditions_names

#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
  private

  ! Information of each element of the FE space
  type, extends(migratory_element) :: fem_element
     
     ! Reference element info          
     type(fem_fixed_info_pointer), allocatable :: f_inf(:)    ! Topology of the reference finite element
     type(fem_fixed_info), pointer :: p_geo_info => NULL()    ! Topology of the reference geometry ( idem fe w/ p=1)
     integer(ip),      allocatable :: order(:)                ! Order per variable
     type(volume_integrator_pointer), allocatable :: integ(:) ! Pointer to integration parameters
     ! order in f_inf, it can be eliminated

     ! Problem and approximation
     integer(ip)                   :: problem           ! Problem to be solved
     integer(ip)                   :: num_vars          ! Number of variables of the problem
     integer(ip)                   :: approximation     ! Discretization to be used

     ! Connectivity
     integer(ip)       , allocatable :: continuity(:)     ! Continuity flag per variable
     type(list_pointer), allocatable :: nodes_object(:)   ! Nodes per object (including interior) (nvars)
     integer(ip)                     :: material          ! Material ! SB.alert : material can be used as p   
     ! use of material still unclear

     ! Local to global 
     integer(ip)     , allocatable   :: elem2dof(:,:)   ! Map from elem to dof
     
     ! Unknown + other values
     real(rp)        , allocatable :: unkno(:,:,:)      ! Values of the solution on the nodes of the elem  (max_num_nodes, nvars, time_steps_to_store)
     real(rp)        , allocatable :: nodal_properties(:,:)   ! Values of (interpolated) properties on the nodes of the elem 
                                                              ! (max_num_nodes, num_nodal_props)
                                                              ! They can be used to store postprocessing fields, e.g. vorticity in nsi
     real(rp)        , allocatable :: gauss_properties(:,:,:) ! Gauss point level properties with history, e.g. subscales,  rank?

     ! Boundary conditions
     integer(ip), allocatable :: bc_code(:,:)   ! Boundary Condition values
     
     ! Auxiliary working arrays (element matrix and vector)
     type(array_rp2), pointer :: p_mat ! Pointer to the elemental matrix
     type(array_rp1), pointer :: p_vec ! Pointer to the elemental vector

   contains
     procedure :: size   => fem_element_size
     procedure :: pack   => fem_element_pack
     procedure :: unpack => fem_element_unpack
  end type fem_element

  ! Information relative to the faces
  type fem_face
     
     ! Reference face info
     type(element_face_integrator) :: integ(2)  ! Pointer to face integration

     ! Face mesh info
     integer(ip)               :: face_object
     integer(ip)               :: neighbor_element(2) ! Neighbor elements
     integer(ip)               :: local_face(2)       ! Face pos in element

     ! Auxiliary working arrays (face+element matrix and vector)
     type(array_rp2), pointer  :: p_mat ! Pointer to the elemental matrix
     type(array_rp1), pointer  :: p_vec ! Pointer to face integration vector

     !type(array_ip1), allocatable:: o2n(2)           ! permutation of the gauss points in elem2
     ! SB.alert : temporary, it is a lot of memory, and should be handled via a hash table
  end type fem_face

  ! Types
  public :: fem_element, fem_face

  ! Methods
  public :: fem_element_print, fem_element_free_unpacked, impose_strong_dirichlet_data

contains
  subroutine fem_element_print ( lunou, elm )
    implicit none
    integer(ip)      , intent(in) :: lunou
    type(fem_element), intent(in) :: elm

    integer(ip) :: ivar

    write (lunou, '(a)')     '*** begin finite element data structure ***'
    write (lunou, '(a,i10)') 'Problem: ', elm%problem
    write (lunou,*) 'Element dofs: ', elm%elem2dof

    write (lunou,*) 'Number of unknowns: ', elm%num_vars
    write (lunou,*) 'Order of each variable: ', elm%order
    write (lunou,*) 'Continuity of each variable: ', size(elm%continuity)
    write (lunou,*) 'Continuity of each variable: ', elm%continuity
    write (lunou,*) 'Element material: ', elm%material
    write (lunou,*) 'Boundary conditions code: ', elm%bc_code

    write (lunou,*) 'Fixed info of each interpolation: '
    do ivar=1, elm%num_vars
       write (lunou, *) 'Type: ', elm%f_inf(ivar)%p%ftype
       write (lunou, *) 'Order: ', elm%f_inf(ivar)%p%order
       write (lunou, *) 'Nobje: ', elm%f_inf(ivar)%p%nobje
       write (lunou, *) 'Nnode: ', elm%f_inf(ivar)%p%nnode
       write (lunou, *) 'Nobje_dim: ', elm%f_inf(ivar)%p%nobje_dim
       write (lunou, *) 'Nodes_obj: ', elm%f_inf(ivar)%p%nodes_obj
       write (lunou, *) 'ndxob%p:  ', elm%f_inf(ivar)%p%ndxob%p
       write (lunou, *) 'ndxob%l:  ', elm%f_inf(ivar)%p%ndxob%l
       write (lunou, *) 'ntxob%p:  ', elm%f_inf(ivar)%p%ntxob%p
       write (lunou, *) 'ntxob%l:  ', elm%f_inf(ivar)%p%ntxob%l
       write (lunou, *) 'crxob%p:  ', elm%f_inf(ivar)%p%crxob%p
       write (lunou, *) 'crxob%l:  ', elm%f_inf(ivar)%p%crxob%l
    end do

    write (lunou,*) 'Unknown values: ', elm%unkno

  end subroutine fem_element_print

   ! SB.alert : to be thought now

  subroutine fem_element_size (my, n)
    implicit none
    class(fem_element), intent(in)  :: my
    integer(ip)            , intent(out) :: n
    
    ! Locals
    integer(ieep) :: mold(1)
    integer(ip)   :: size_of_ip
    
    size_of_ip   = size(transfer(1_ip ,mold))

    n = size_of_ip*3 + 2*size_of_ip*(my%num_vars)

  end subroutine fem_element_size

  subroutine fem_element_pack (my, n, buffer)
    implicit none
    class(fem_element), intent(in)  :: my
    integer(ip)            , intent(in)   :: n
    integer(ieep)            , intent(out)  :: buffer(n)
    
    ! Locals
    integer(ieep) :: mold(1)
    integer(ip) :: size_of_ip

    integer(ip) :: start, end

    size_of_ip   = size(transfer(1_ip ,mold))

    start = 1
    end   = start + size_of_ip -1
    buffer(start:end) = transfer(my%num_vars,mold)

    start = end + 1
    end   = start + size_of_ip - 1
    buffer(start:end) = transfer(my%problem,mold)

    start = end + 1
    end   = start + size_of_ip - 1
    buffer(start:end) = transfer(my%material,mold)

    start = end + 1
    end   = start + my%num_vars*size_of_ip - 1
    buffer(start:end) = transfer(my%order,mold)

    start = end + 1
    end   = start + my%num_vars*size_of_ip - 1
    buffer(start:end) = transfer(my%continuity,mold)

  end subroutine fem_element_pack

  subroutine fem_element_unpack(my, n, buffer)
    implicit none
    class(fem_element), intent(inout) :: my
    integer(ip)            , intent(in)     :: n
    integer(ieep)            , intent(in)     :: buffer(n)

    ! Locals
    integer(ieep) :: mold(1)
    integer(ip) :: size_of_ip
    integer(ip) :: start, end
    
    size_of_ip   = size(transfer(1_ip ,mold))

    start = 1
    end   = start + size_of_ip -1
    my%num_vars  = transfer(buffer(start:end), my%num_vars)

    start = end + 1
    end   = start + size_of_ip - 1
    my%problem  = transfer(buffer(start:end), my%problem)

    start = end + 1
    end   = start + size_of_ip - 1
    my%material  = transfer(buffer(start:end), my%material)

    call memalloc( my%num_vars, my%order, __FILE__, __LINE__ )

    start = end + 1
    end   = start + my%num_vars*size_of_ip - 1
    my%order = transfer(buffer(start:end), my%order)
    
    call memalloc( my%num_vars, my%continuity, __FILE__, __LINE__ )
     
    start = end + 1
    end   = start + my%num_vars*size_of_ip - 1
    my%continuity = transfer(buffer(start:end), my%continuity)
    
  end subroutine fem_element_unpack

  subroutine fem_element_free_unpacked(my)
    implicit none
    type(fem_element), intent(inout) :: my

    call memfree( my%order, __FILE__, __LINE__ )
    call memfree( my%continuity, __FILE__, __LINE__ )
    
  end subroutine fem_element_free_unpacked

 !=============================================================================
  subroutine impose_strong_dirichlet_data (el) 
    implicit none
    ! Parameters
    type(fem_element)    , intent(inout)  :: el

    ! Locals
    integer(ip) :: iprob, count, ivars, inode, idof
    
    iprob = el%problem
    count = 0

    !write (*,*) 'start assembly bc of matrix : ', el%p_mat%a
    do ivars = 1, el%num_vars
       do inode = 1,el%f_inf(ivars)%p%nnode
          count = count + 1
          idof = el%elem2dof(inode,ivars)
          if ( idof  == 0 ) then
             el%p_vec%a(:) = el%p_vec%a(:) - el%p_mat%a(:,count)*el%unkno(inode,ivars,1)
             !write (*,*) 'add to vector', -el%p_mat%a(:,count)*el%unkno(inode,ivars,1)
          end if
       end do
    end do

    !write(*,*) 'elvec :', el%p_vec%a

  end subroutine impose_strong_dirichlet_data

end module fem_element_names
