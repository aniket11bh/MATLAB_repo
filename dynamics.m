function xdot=dynamics(t,X)

kpc2km = 30856775814671900;
myr = 1e6*365*86400;

k0 = 0.00287729;
k1 =  0.0023821 ;
k2 = -0.0010625 ;
k3 = 0.000198502 ;
k4 = -1.88428e-05 ;
k5 = 9.70521e-07 ;
k6 = -2.70559e-08; 
k7 = 3.7516e-10 ;
k8 = -1.94316e-12;

x=X(1);y=X(2);z=X(3);vx=X(4);vy=X(5);vz=X(6);
r= sqrt(x^2+y^2+z^2); 

f2= -(1/r^2) * ( (1/ (k0 + k1 * r + k2 * r^2 + k3*r^3 + k4 * r^4 +k5*r^5 +k6*r^6 + k7*r^7 +k8* r^8))*myr/kpc2km)^2 * [x;y;z]; % KM/S^2


phidot = [X(7:12)';X(13:18)';X(19:24)';X(25:30)';X(31:36)';X(37:42)']* jacobianreturn(X(1),X(2),X(3),X(4),X(5),X(6));


xdot = [X(4);X(5);X(6); f2;phidot(1,1:6)';phidot(2,1:6)';phidot(3,1:6)';phidot(4,1:6)';phidot(5,1:6)';phidot(6,1:6)'];
