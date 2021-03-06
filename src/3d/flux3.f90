

!     ==================================================================
    subroutine flux3(ixyz,maxm,num_eqn,num_waves,num_ghost,mx, &
    q1d,dtdx1d,dtdy,dtdz,aux1,aux2,aux3,num_aux, &
    method,mthlim,qadd,fadd,gadd,hadd,cfl1d, &
    wave,s,amdq,apdq,cqxx, &
    bmamdq,bmapdq,bpamdq,bpapdq, &
    cmamdq,cmapdq,cpamdq,cpapdq, &
    cmamdq2,cmapdq2,cpamdq2,cpapdq2, &
    bmcqxxp,bpcqxxp,bmcqxxm,bpcqxxm, &
    cmcqxxp,cpcqxxp,cmcqxxm,cpcqxxm, &
    bmcmamdq,bmcmapdq,bpcmamdq,bpcmapdq, &
    bmcpamdq,bmcpapdq,bpcpamdq,bpcpapdq, &
    rpn3,rpt3,rptt3,use_fwave)
!     ==================================================================

!     # Compute the modification to fluxes f, g and h that are generated by
!     # all interfaces along a 1D slice of the 3D patch.
!     #    ixyz = 1  if it is a slice in x
!     #           2  if it is a slice in y
!     #           3  if it is a slice in z
!     # This value is passed into the Riemann solvers. The flux modifications
!     # go into the arrays fadd, gadd and hadd.  The notation is written
!     # assuming we are solving along a 1D slice in the x-direction.

!     # fadd(i,.) modifies F to the left of cell i
!     # gadd(i,.,1,slice) modifies G below cell i (in the z-direction)
!     # gadd(i,.,2,slice) modifies G above cell i
!     #                   The G flux in the surrounding slices may
!     #                   also be updated.
!     #                   slice  =  -1     The slice below in y-direction
!     #                   slice  =   0     The slice used in the 2D method
!     #                   slice  =   1     The slice above in y-direction
!     # hadd(i,.,1,slice) modifies H below cell i (in the y-direction)
!     # hadd(i,.,2,slice) modifies H above cell i
!     #                   The H flux in the surrounding slices may
!     #                   also be updated.
!     #                   slice  =  -1     The slice below in z-direction
!     #                   slice  =   0     The slice used in the 2D method
!     #                   slice  =   1     The slice above in z-direction
!     #
!     # The method used is specified by method(2) and method(3):

!        method(2) = 1 No correction waves
!                  = 2 if second order correction terms are to be added, with
!                      a flux limiter as specified by mthlim.  No transverse
!                      propagation of these waves.

!         method(3) specify how the transverse wave propagation
!         of the increment wave and the correction wave are performed.
!         Note that method(3) is given by a two digit number, in
!         contrast to what is the case for claw2. It is convenient
!         to define the scheme using the pair (method(2),method(3)).

!         method(3) <  0 Gives dimensional splitting using Godunov
!                        splitting, i.e. formally first order
!                        accurate.
!                      0 Gives the Donor cell method. No transverse
!                        propagation of neither the increment wave
!                        nor the correction wave.
!                   = 10 Transverse propagation of the increment wave
!                        as in 2D. Note that method (2,10) is
!                        unconditionally unstable.
!                   = 11 Corner transport upwind of the increment
!                        wave. Note that method (2,11) also is
!                        unconditionally unstable.
!                   = 20 Both the increment wave and the correction
!                        wave propagate as in the 2D case. Only to
!                        be used with method(2) = 2.
!                   = 21 Corner transport upwind of the increment wave,
!                        and the correction wave propagates as in 2D.
!                        Only to be used with method(2) = 2.
!                   = 22 3D propagation of both the increment wave and
!                        the correction wave. Only to be used with
!                        method(2) = 2.

!         Recommended settings:   First order schemes:
!                                       (1,10) Stable for CFL < 1/2
!                                       (1,11) Stable for CFL < 1
!                                 Second order schemes:
!                                        (2,20) Stable for CFL < 1/2
!                                        (2,22) Stable for CFL < 1

!         WARNING! The schemes (2,10), (2,11) are unconditionally
!                  unstable.

!                       ----------------------------------

!     Note that if method(6)=1 then the capa array comes into the second
!     order correction terms, and is already included in dtdx1d:
!     If ixyz = 1 then
!        dtdx1d(i) = dt/dx                      if method(6) = 0
!                  = dt/(dx*capa(i,jcom,kcom))  if method(6) = 1
!     If ixyz = 2 then
!        dtdx1d(j) = dt/dy                      if method(6) = 0
!                  = dt/(dy*capa(icom,j,kcom))  if method(6) = 1
!     If ixyz = 3 then
!        dtdx1d(k) = dt/dz                      if method(6) = 0
!                  = dt/(dz*capa(icom,jcom,k))  if method(6) = 1

!     Notation:
!        The jump in q (q1d(i,:)-q1d(i-1,:))  is split by rpn3 into
!            amdq =  the left-going flux difference  A^- Delta q
!            apdq = the right-going flux difference  A^+ Delta q
!        Each of these is split by rpt3 into
!            bmasdq = the down-going transverse flux difference B^- A^* Delta q
!            bpasdq =   the up-going transverse flux difference B^+ A^* Delta q
!        where A^* represents either A^- or A^+.


    implicit real*8(a-h,o-z)
    external rpn3,rpt3, rptt3
    dimension     q1d(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension    amdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension    apdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bmamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bmapdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpapdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension   cqxx(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension   qadd(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension   fadd(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension   gadd(num_eqn,2,-1:1,1-num_ghost:maxm+num_ghost)
    dimension   hadd(num_eqn,2,-1:1,1-num_ghost:maxm+num_ghost)

    dimension  cmamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cmapdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cpamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cpapdq(num_eqn,1-num_ghost:maxm+num_ghost)

    dimension  cmamdq2(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cmapdq2(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cpamdq2(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cpapdq2(num_eqn,1-num_ghost:maxm+num_ghost)

    dimension  bmcqxxm(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpcqxxm(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cmcqxxm(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cpcqxxm(num_eqn,1-num_ghost:maxm+num_ghost)

    dimension  bmcqxxp(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpcqxxp(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cmcqxxp(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  cpcqxxp(num_eqn,1-num_ghost:maxm+num_ghost)

    dimension  bpcmamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpcmapdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpcpamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bpcpapdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bmcmamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bmcmapdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bmcpamdq(num_eqn,1-num_ghost:maxm+num_ghost)
    dimension  bmcpapdq(num_eqn,1-num_ghost:maxm+num_ghost)

    dimension dtdx1d(1-num_ghost:maxm+num_ghost)
    dimension aux1(num_aux,1-num_ghost:maxm+num_ghost,3)
    dimension aux2(num_aux,1-num_ghost:maxm+num_ghost,3)
    dimension aux3(num_aux,1-num_ghost:maxm+num_ghost,3)

    dimension    s(num_waves,1-num_ghost:maxm+num_ghost)
    dimension  wave(num_eqn,num_waves,1-num_ghost:maxm+num_ghost)

    dimension method(7),mthlim(num_waves)
    logical :: limit, use_fwave
    common/comxyt/dtcom,dxcom,dycom,dzcom,tcom,icom,jcom,kcom

!f2py external rpn3, rpt3, rptt3
!f2py intent(callback) rpn3,rpt3, rptt3

    limit = .false.
    do 5 mw=1,num_waves
        if (mthlim(mw) > 0) limit = .TRUE. 
    5 END DO

!     # initialize flux increments:
!     -----------------------------

    forall (m = 1:num_eqn, i = 1-num_ghost:mx+num_ghost)
    qadd(m,i) = 0.d0
    fadd(m,i) = 0.d0
    end forall
    forall (m=1:num_eqn,k=1:2, j = -1:1, i = 1-num_ghost:mx+num_ghost)
    gadd(m, k, j, i) = 0.d0
    hadd(m, k, j, i) = 0.d0
    end forall

!     # local method parameters
    if (method(3) < 0) then
    !        # dimensional splitting
        m3 = -1
        m4 = 0
    else
    !        # unsplit method
        m3 = method(3)/10
        m4 = method(3) - 10*m3
    endif

!     -----------------------------------------------------------
!     # solve normal Riemann problem and compute Godunov updates
!     -----------------------------------------------------------

!     # aux2(1-num_ghost,1,2) is the start of a 1d array now used by rpn3

    call rpn3(ixyz,maxm,num_eqn,num_waves,num_aux,num_ghost,mx,q1d,q1d, &
    aux2(1,1-num_ghost,2),aux2(1,1-num_ghost,2), &
    wave,s,amdq,apdq)


!     # Set qadd for the donor-cell upwind method (Godunov)
    forall (m = 1:num_eqn, i = 1:mx+1)
    qadd(m,i) = qadd(m,i) - dtdx1d(i)*apdq(m,i)
    qadd(m,i-1) = qadd(m,i-1) - dtdx1d(i-1)*amdq(m,i)
    end forall

!     # compute maximum wave speed for checking Courant number:
    cfl1d = 0.d0
    do i=1,mx+1
        do mw=1,num_waves
        !          # if s>0 use dtdx1d(i) to compute CFL,
        !          # if s<0 use dtdx1d(i-1) to compute CFL:
            cfl1d = dmax1(cfl1d, dtdx1d(i)*s(mw,i), &
            -dtdx1d(i-1)*s(mw,i))
        end do
    end do

    if (method(2) == 1) go to 130

!     -----------------------------------------------------------
!     # modify F fluxes for second order q_{xx} correction terms:
!     #   F fluxes are in normal, or x-like, direction
!     -----------------------------------------------------------

!     # apply limiter to waves:
    if (limit) call limiter(maxm,num_eqn,num_waves,num_ghost,mx,wave, &
    s,mthlim)

    if (.not. use_fwave) then
        do i = 2-num_ghost,mx+num_ghost
            ! modified in Version 4.3 to use average only in cqxx, not transverse
            dtdxave = 0.5d0 * (dtdx1d(i-1) + dtdx1d(i))

            do m = 1, num_eqn
                cqxx(m,i) = 0.d0
            end do
            do mw = 1,num_waves
                do m = 1,num_eqn
                    cqxx(m,i) = cqxx(m,i) + 0.5d0 * dabs(s(mw,i)) &
                        * (1.d0 - dabs(s(mw,i))*dtdxave) * wave(m,mw,i)
                end do
            end do
            do m = 1,num_eqn
                fadd(m,i) = fadd(m,i) + cqxx(m,i)
            end do
        end do
    else    ! Use f-waves
        do i = 2-num_ghost,mx+num_ghost
            dtdxave = 0.5d0 * (dtdx1d(i-1) + dtdx1d(i))

            do m = 1, num_eqn
                cqxx(m,i) = 0.d0
            end do
            do mw = 1,num_waves
                do m = 1,num_eqn
                    cqxx(m,i) = cqxx(m,i) + 0.5d0 * dsign(1.d0, s(mw,i)) &
                        * (1.d0 - dabs(s(mw,i))*dtdxave) * wave(m,mw,i)
                end do
            end do
            do m = 1,num_eqn
                fadd(m,i) = fadd(m,i) + cqxx(m,i)
            end do
        end do
    end if

    130 continue

    if (m3 <= 0) return !! no transverse propagation

!     --------------------------------------------
!     # TRANSVERSE PROPAGATION
!     --------------------------------------------

!     # split the left-going flux difference into down-going and up-going
!     # flux differences (in the y-direction).

    call rpt3(ixyz,2,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx,q1d,q1d, &
              aux1,aux2,aux3,amdq,bmamdq,bpamdq)

!     # split the right-going flux difference into down-going and up-going
!     # flux differences (in the y-direction).

    call rpt3(ixyz,2,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx,q1d,q1d, &
              aux1,aux2,aux3,apdq,bmapdq,bpapdq)

!     # split the left-going flux difference into down-going and up-going
!     # flux differences (in the z-direction).

    call rpt3(ixyz,3,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx,q1d,q1d, &
              aux1,aux2,aux3,amdq,cmamdq,cpamdq)

!     # split the right-going flux difference into down-going and up-going
!     # flux differences (in the y-direction).

    call rpt3(ixyz,3,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx,q1d,q1d, &
              aux1,aux2,aux3,apdq,cmapdq,cpapdq)

!     # Split the correction wave into transverse propagating waves
!     # in the y-direction and z-direction.

    if (m3 == 2) then
        if (num_aux > 0) then
        !            # The corrections cqxx affect both cell i-1 to left and cell i
        !            # to right of interface.  Transverse splitting will affect
        !            # fluxes on both sides.
        !            # If there are aux arrays, then we must split cqxx twice in
        !            # each transverse direction, once with imp=1 and once with imp=2:

        !            # imp = 1 or 2 is used to indicate whether we are propagating
        !            # amdq or apdq, i.e. cqxxm or cqxxp

        !            # in the y-like direction with imp=1
            call rpt3(ixyz,2,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
                      q1d,q1d,aux1,aux2,aux3,cqxx,bmcqxxm,bpcqxxm)

        !            # in the y-like direction with imp=2
            call rpt3(ixyz,2,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
                      q1d,q1d,aux1,aux2,aux3,cqxx,bmcqxxp,bpcqxxp)

        !            # in the z-like direction with imp=1
            call rpt3(ixyz,3,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
                      q1d,q1d,aux1,aux2, auxnum_aux,cqxx,cmcqxxm,cpcqxxm)

        !            # in the z-like direction with imp=2
            call rpt3(ixyz,3,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
                      q1d,q1d,aux1,aux2,aux3,cqxx,cmcqxxp,cpcqxxp)
        else
        !            # aux arrays aren't being used, so we only need to split
        !            # cqxx once in each transverse direction and the same result can
        !            # presumably be used to left and right.
        !            # Set imp = 0 since this shouldn't be needed in rpt3 in this case.

        !            # in the y-like direction
            call rpt3(ixyz,2,0,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
            q1d,q1d,aux1,aux2,aux3,cqxx,bmcqxxm,bpcqxxm)

        !            # in the z-like direction
            call rpt3(ixyz,3,0,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
            q1d,q1d,aux1,aux2,aux3,cqxx,cmcqxxm,cpcqxxm)

        !             # use the same splitting to left and right:
            forall (m = 1:num_eqn, i = 0:mx+2)
            bmcqxxp(m,i) = bmcqxxm(m,i)
            bpcqxxp(m,i) = bpcqxxm(m,i)
            cmcqxxp(m,i) = cmcqxxm(m,i)
            cpcqxxp(m,i) = cpcqxxm(m,i)
            end forall
        endif
    endif

!      --------------------------------------------
!      # modify G fluxes in the y-like direction
!      --------------------------------------------

!     # If the correction wave also propagates in a 3D sense, incorporate
!     # cpcqxx,... into cmamdq, cpamdq, ... so that it is split also.

    if(m4 == 1)then
        forall (m = 1:num_eqn, i = 0:mx+2)
        cpapdq2(m,i) = cpapdq(m,i)
        cpamdq2(m,i) = cpamdq(m,i)
        cmapdq2(m,i) = cmapdq(m,i)
        cmamdq2(m,i) = cmamdq(m,i)
        end forall
    else if(m4 == 2)then
        forall (m = 1:num_eqn, i = 0:mx+2)
        cpapdq2(m,i) = cpapdq(m,i) - 3.d0*cpcqxxp(m,i)
        cpamdq2(m,i) = cpamdq(m,i) + 3.d0*cpcqxxm(m,i)
        cmapdq2(m,i) = cmapdq(m,i) - 3.d0*cmcqxxp(m,i)
        cmamdq2(m,i) = cmamdq(m,i) + 3.d0*cmcqxxm(m,i)
        end forall
    endif

!     # The transverse flux differences in the z-direction are split
!     # into waves propagating in the y-direction. If m4 = 2,
!     # then the transverse propagating correction waves in the z-direction
!     # are also split. This yields terms of the form BCAu_{xzy} and
!     # BCAAu_{xxzy}.

    if( m4 > 0 )then
        call rptt3(ixyz,2,2,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,cpapdq2,bmcpapdq,bpcpapdq)
        call rptt3(ixyz,2,1,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,cpamdq2,bmcpamdq,bpcpamdq)
        call rptt3(ixyz,2,2,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,cmapdq2,bmcmapdq,bpcmapdq)
        call rptt3(ixyz,2,1,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,cmamdq2,bmcmamdq,bpcmamdq)
    endif

!     -----------------------------
!     # The updates for G fluxes :
!     -----------------------------

    do 180 i = 1, mx+1
        do 180 m=1,num_eqn
        
        !           # Transverse propagation of the increment waves
        !           # between cells sharing interfaces, i.e. the 2D approach.
        !           # Yields BAu_{xy}.
        
            gadd(m,1,0,i-1) = gadd(m,1,0,i-1) &
            - 0.5d0*dtdx1d(i-1)*bmamdq(m,i)
            gadd(m,2,0,i-1) = gadd(m,2,0,i-1) &
            - 0.5d0*dtdx1d(i-1)*bpamdq(m,i)
            gadd(m,1,0,i)   = gadd(m,1,0,i) &
            - 0.5d0*dtdx1d(i)*bmapdq(m,i)
            gadd(m,2,0,i)   = gadd(m,2,0,i) &
            - 0.5d0*dtdx1d(i)*bpapdq(m,i)
        
        !           # Transverse propagation of the increment wave (and the
        !           # correction wave if m4=2) between cells
        !           # only having a corner or edge in common. Yields terms of the
        !           # BCAu_{xzy} and BCAAu_{xxzy}.
        
            if( m4 > 0 )then
            

                gadd(m,2,0,i) = gadd(m,2,0,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdz &
                * (bpcpapdq(m,i) - bpcmapdq(m,i))
                gadd(m,1,0,i) = gadd(m,1,0,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdz &
                * (bmcpapdq(m,i) - bmcmapdq(m,i))


                gadd(m,2,1,i) = gadd(m,2,1,i) &
                - (1.d0/6.d0)*dtdx1d(i)*dtdz &
                * bpcpapdq(m,i)
                gadd(m,1,1,i) = gadd(m,1,1,i) &
                - (1.d0/6.d0)*dtdx1d(i)*dtdz &
                * bmcpapdq(m,i)
                gadd(m,2,-1,i) = gadd(m,2,-1,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdz &
                * bpcmapdq(m,i)
                gadd(m,1,-1,i) = gadd(m,1,-1,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdz &
                * bmcmapdq(m,i)
            
                gadd(m,2,0,i-1) = gadd(m,2,0,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdz &
                * (bpcpamdq(m,i) - bpcmamdq(m,i))
                gadd(m,1,0,i-1) = gadd(m,1,0,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdz &
                * (bmcpamdq(m,i) - bmcmamdq(m,i))


                gadd(m,2,1,i-1) = gadd(m,2,1,i-1) &
                - (1.d0/6.d0)*dtdx1d(i-1)*dtdz &
                * bpcpamdq(m,i)
                gadd(m,1,1,i-1) = gadd(m,1,1,i-1) &
                - (1.d0/6.d0)*dtdx1d(i-1)*dtdz &
                * bmcpamdq(m,i)
                gadd(m,2,-1,i-1) = gadd(m,2,-1,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdz &
                * bpcmamdq(m,i)
                gadd(m,1,-1,i-1) = gadd(m,1,-1,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdz &
                * bmcmamdq(m,i)
            
            endif
        
        !           # Transverse propagation of the correction wave between
        !           # cells sharing faces. This gives BAAu_{xxy}.
        
            if(m3 < 2) go to 180
            gadd(m,2,0,i)   = gadd(m,2,0,i) &
            + dtdx1d(i)*bpcqxxp(m,i)
            gadd(m,1,0,i)   = gadd(m,1,0,i) &
            + dtdx1d(i)*bmcqxxp(m,i)
            gadd(m,2,0,i-1) = gadd(m,2,0,i-1) &
            - dtdx1d(i-1)*bpcqxxm(m,i)
            gadd(m,1,0,i-1) = gadd(m,1,0,i-1) &
            - dtdx1d(i-1)*bmcqxxm(m,i)
        
    180 END DO


!      --------------------------------------------
!      # modify H fluxes in the z-like direction
!      --------------------------------------------

!     # If the correction wave also propagates in a 3D sense, incorporate
!     # cqxx into bmamdq, bpamdq, ... so that is is split also.

    if(m4 == 2)then
        forall (m = 1:num_eqn, i = 0:mx+2)
        bpapdq(m,i) = bpapdq(m,i) - 3.d0*bpcqxxp(m,i)
        bpamdq(m,i) = bpamdq(m,i) + 3.d0*bpcqxxm(m,i)
        bmapdq(m,i) = bmapdq(m,i) - 3.d0*bmcqxxp(m,i)
        bmamdq(m,i) = bmamdq(m,i) + 3.d0*bmcqxxm(m,i)
        end forall
    endif

!     # The transverse flux differences in the y-direction are split
!     # into waves propagating in the z-direction. If m4 = 2,
!     # then the transverse propagating correction waves in the y-direction
!     # are also split. This yields terms of the form BCAu_{xzy} and
!     # BCAAu_{xxzy}.

!     # note that the output to rptt3 below should logically be named
!     # cmbsasdq and cpbsasdq rather than bmcsasdq and bpcsasdq, but
!     # we are re-using the previous storage rather than requiring new arrays.

    if( m4 > 0 )then
        call rptt3(ixyz,3,2,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,bpapdq,bmcpapdq,bpcpapdq)
        call rptt3(ixyz,3,1,2,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,bpamdq,bmcpamdq,bpcpamdq)
        call rptt3(ixyz,3,2,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,bmapdq,bmcmapdq,bpcmapdq)
        call rptt3(ixyz,3,1,1,maxm,num_eqn,num_waves,num_aux,num_ghost,mx, &
        q1d,q1d,aux1,aux2,aux3,bmamdq,bmcmamdq,bpcmamdq)
    endif

!     -----------------------------
!     # The updates for H fluxes :
!     -----------------------------

    do 200 i = 1, mx+1
        do 200 m=1,num_eqn
        
        !           # Transverse propagation of the increment waves
        !           # between cells sharing interfaces, i.e. the 2D approach.
        !           # Yields CAu_{xy}.
        
            hadd(m,1,0,i-1) = hadd(m,1,0,i-1) &
            - 0.5d0*dtdx1d(i-1)*cmamdq(m,i)
            hadd(m,2,0,i-1) = hadd(m,2,0,i-1) &
            - 0.5d0*dtdx1d(i-1)*cpamdq(m,i)
            hadd(m,1,0,i)   = hadd(m,1,0,i) &
            - 0.5d0*dtdx1d(i)*cmapdq(m,i)
            hadd(m,2,0,i)   = hadd(m,2,0,i) &
            - 0.5d0*dtdx1d(i)*cpapdq(m,i)
        
        !           # Transverse propagation of the increment wave (and the
        !           # correction wave if m4=2) between cells
        !           # only having a corner or edge in common. Yields terms of the
        !           # CBAu_{xzy} and CBAAu_{xxzy}.
        
            if( m4 > 0 )then
            
                hadd(m,2,0,i)  = hadd(m,2,0,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdy &
                * (bpcpapdq(m,i) - bpcmapdq(m,i))
                hadd(m,1,0,i)  = hadd(m,1,0,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdy &
                * (bmcpapdq(m,i) - bmcmapdq(m,i))


                hadd(m,2,1,i)  = hadd(m,2,1,i) &
                - (1.d0/6.d0)*dtdx1d(i)*dtdy &
                * bpcpapdq(m,i)
                hadd(m,1,1,i)  = hadd(m,1,1,i) &
                - (1.d0/6.d0)*dtdx1d(i)*dtdy &
                * bmcpapdq(m,i)
                hadd(m,2,-1,i) = hadd(m,2,-1,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdy &
                * bpcmapdq(m,i)
                hadd(m,1,-1,i) = hadd(m,1,-1,i) &
                + (1.d0/6.d0)*dtdx1d(i)*dtdy &
                * bmcmapdq(m,i)
            
                hadd(m,2,0,i-1)  = hadd(m,2,0,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdy &
                * (bpcpamdq(m,i) - bpcmamdq(m,i))
                hadd(m,1,0,i-1)  = hadd(m,1,0,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdy &
                * (bmcpamdq(m,i) - bmcmamdq(m,i))


                hadd(m,2,1,i-1)  = hadd(m,2,1,i-1) &
                - (1.d0/6.d0)*dtdx1d(i-1)*dtdy &
                * bpcpamdq(m,i)
                hadd(m,1,1,i-1)  = hadd(m,1,1,i-1) &
                - (1.d0/6.d0)*dtdx1d(i-1)*dtdy &
                * bmcpamdq(m,i)
                hadd(m,2,-1,i-1) = hadd(m,2,-1,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdy &
                * bpcmamdq(m,i)
                hadd(m,1,-1,i-1) = hadd(m,1,-1,i-1) &
                + (1.d0/6.d0)*dtdx1d(i-1)*dtdy &
                * bmcmamdq(m,i)
            
            endif
        
        !           # Transverse propagation of the correction wave between
        !           # cells sharing faces. This gives CAAu_{xxy}.
        
            if(m3 < 2) go to 200
            hadd(m,2,0,i)   = hadd(m,2,0,i) &
            + dtdx1d(i)*cpcqxxp(m,i)
            hadd(m,1,0,i)   = hadd(m,1,0,i) &
            + dtdx1d(i)*cmcqxxp(m,i)
            hadd(m,2,0,i-1) = hadd(m,2,0,i-1) &
            - dtdx1d(i-1)*cpcqxxm(m,i)
            hadd(m,1,0,i-1) = hadd(m,1,0,i-1) &
            - dtdx1d(i-1)*cmcqxxm(m,i)
        
    200 END DO

    return
    end subroutine flux3


