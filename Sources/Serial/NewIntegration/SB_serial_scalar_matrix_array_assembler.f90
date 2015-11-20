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
module SB_serial_scalar_matrix_array_assembler_names
  use types_names
  use dof_descriptor_names
  use allocatable_array_names

  ! Abstract modules
  use SB_matrix_array_assembler_names
  use matrix_names
  use array_names

  ! Concrete implementations
  use serial_scalar_matrix_names
  use serial_scalar_array_names

  implicit none
# include "debug.i90"
  private

  type, extends(SB_matrix_array_assembler_t) :: SB_serial_scalar_matrix_array_assembler_t
contains
  procedure :: assembly => serial_scalar_matrix_array_assembler_assembly
end type

! Data types
public :: SB_serial_scalar_matrix_array_assembler_t
public :: element_serial_scalar_matrix_assembly, element_serial_scalar_array_assembly

contains
subroutine serial_scalar_matrix_array_assembler_assembly(this,el2dof,elmat,elvec) 
 implicit none
 class(SB_serial_scalar_matrix_array_assembler_t), intent(inout) :: this
 real(rp), intent(in) :: elmat(:,:), elvec(:)
 integer(ip), intent(in) :: el2dof(:)

 class(matrix_t), pointer :: matrix
 class(array_t) , pointer :: array

 matrix => this%get_matrix()
 array  => this%get_array()

 select type(matrix)
    class is(serial_scalar_matrix_t)
    call element_serial_scalar_matrix_assembly( matrix,  el2dof,  elmat )
    class default
    check(.false.)
 end select

 select type(array)
    class is(serial_scalar_array_t)
    call element_serial_scalar_array_assembly( array,  el2dof,  elvec )
    class default
    check(.false.)
 end select
end subroutine serial_scalar_matrix_array_assembler_assembly

subroutine element_serial_scalar_matrix_assembly(   a, el2dof, elmat, iblock, jblock )
 implicit none
 ! Parameters
 type(serial_scalar_matrix_t)         , intent(inout) :: a
 real(rp), intent(in) :: elmat(:,:)
 integer(ip), intent(in) :: el2dof(:)
 integer(ip), intent(in), optional      :: iblock, jblock

 integer(ip) :: iprob, ndof_i, idof, ndof_j, jdof 
 integer(ip) :: inode, jnode, k, iblock_, jblock_

 iblock_ = 1
 jblock_ = 1
 if ( present(iblock) ) iblock_ = iblock
 if ( present(jblock) ) jblock_ = jblock

 !iprob = fe%problem
 iprob = 1
 ndof_i = size(elmat,1)
 ndof_j = size(elmat,2)

 !if( dof_descriptor%dof_coupl(g_var,k_var) == 1) then
 do inode = 1,ndof_i
    idof = el2dof(inode)
    if ( idof  > 0 ) then
       do jnode = 1,ndof_j
          jdof = el2dof(jnode)
          if (  (.not. a%graph%symmetric_storage) .and. jdof > 0 ) then
             do k = a%graph%ia(idof),a%graph%ia(idof+1)-1
                if ( a%graph%ja(k) == jdof ) exit
             end do
             assert ( k < a%graph%ia(idof+1) )
             a%a(k) = a%a(k) + elmat(inode,jnode)
          else if ( jdof >= idof ) then 
             do k = a%graph%ia(idof),a%graph%ia(idof+1)-1
                if ( a%graph%ja(k) == jdof ) exit
             end do
             assert ( k < a%graph%ia(idof+1) )
             a%a(k) = a%a(k) + elmat(inode,jnode)
          end if
       end do
    end if
 end do

end subroutine element_serial_scalar_matrix_assembly

subroutine element_serial_scalar_array_assembly(  a, el2dof, elvec, iblock )
 implicit none
 ! Parameters
 type(serial_scalar_array_t), intent(inout) :: a
 real(rp), intent(in) :: elvec(:)
 integer(ip), intent(in) :: el2dof(:)
 integer(ip), intent(in), optional :: iblock

 integer(ip) :: iprob,ndof_i
 integer(ip) :: inode, idof, iblock_

 iblock_ = 1
 if ( present(iblock) ) iblock_ = iblock
 !iprob = fe%problem
 iprob = 1

 ndof_i = size(elvec,1)
 do inode = 1,ndof_i
    idof = el2dof(inode)
    if ( idof  > 0 ) then
       a%b(idof) =  a%b(idof) + elvec(inode)
    end if
 end do
end subroutine element_serial_scalar_array_assembly

end module SB_serial_scalar_matrix_array_assembler_names