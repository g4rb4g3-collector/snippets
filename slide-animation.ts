import { ActivatedRouteSnapshot, DetachedRouteHandle, RouteReuseStrategy } from '@angular/router';
import { ComponentRef, Injectable } from '@angular/core';

// Helper: Compare two plain objects
function compareObjects(a: any, b: any): boolean {
  return Object.keys(a).every(prop =>
    b.hasOwnProperty(prop) &&
    (typeof a[prop] === typeof b[prop]) &&
    (
      (typeof a[prop] === "object" && compareObjects(a[prop], b[prop])) ||
      (typeof a[prop] === "function" && a[prop].toString() === b[prop].toString()) ||
      a[prop] == b[prop]
    )
  );
}

// Helper: Generate a unique key for each route
export function getFullPath(route: ActivatedRouteSnapshot): string {
  return route.pathFromRoot
    .map(v => v.url.map(segment => segment.toString()).join("/"))
    .join("/")
    .trim()
    .replace(/\/$/, "");
}

interface StoredRoute {
  route: ActivatedRouteSnapshot;
  handle: DetachedRouteHandle;
}

@Injectable({ providedIn: 'root' })
export class CustomReuseStrategy implements RouteReuseStrategy {
  storedRoutes: Record<string, StoredRoute | null> = {};

  // Should we cache this route when navigating away?
  shouldDetach(route: ActivatedRouteSnapshot): boolean {
    return !!route.data['storeRoute'];
  }

  // Store the handle, indexed by full path
  store(route: ActivatedRouteSnapshot, handle: DetachedRouteHandle): void {
    const key = getFullPath(route);
    this.storedRoutes[key] = { route, handle };
  }

  // Should we reuse a cached handle on navigation?
  shouldAttach(route: ActivatedRouteSnapshot): boolean {
    const key = getFullPath(route);
    const isStored = !!route.routeConfig && !!this.storedRoutes[key];
    if (isStored) {
      const paramsMatch = compareObjects(route.params, this.storedRoutes[key]!.route.params);
      const queryParamsMatch = compareObjects(route.queryParams, this.storedRoutes[key]!.route.queryParams);
      return paramsMatch && queryParamsMatch;
    }
    return false;
  }

  // Retrieve the cached handle
  retrieve(route: ActivatedRouteSnapshot): DetachedRouteHandle | null {
    const key = getFullPath(route);
    if (!route.routeConfig || !this.storedRoutes[key]) return null;
    return this.storedRoutes[key]!.handle;
  }

  // Standard reuse logic, unless 'noReuse' is set in route data
  shouldReuseRoute(prev: ActivatedRouteSnapshot, next: ActivatedRouteSnapshot): boolean {
    const isSameConfig = prev.routeConfig === next.routeConfig;
    const shouldReuse = !next.data['noReuse'];
    return isSameConfig && shouldReuse;
  }

  // Timed purge: Destroys and removes a cached route after a delay (e.g., 500ms)
  removeAfterDelay(fullPath: string, ms: number = 500) {
    setTimeout(() => {
      this.clearRoute(fullPath);
    }, ms);
  }
  
  // Destroys a particular route's cached component
  clearRoute(fullPath: string) {
    if (this.storedRoutes[fullPath]?.handle) {
      this.destroyComponent(this.storedRoutes[fullPath]!.handle);
      this.storedRoutes[fullPath] = null;
    }
  }

  // Destroys all cached components
  clearAllRoutes() {
    for (const key in this.storedRoutes) {
      if (this.storedRoutes[key]?.handle) {
        this.destroyComponent(this.storedRoutes[key]!.handle);
      }
    }
    this.storedRoutes = {};
  }

  // Safely destroy the underlying ComponentRef from a DetachedRouteHandle
  private destroyComponent(handle: DetachedRouteHandle): void {
    const componentRef: ComponentRef<any> = (handle as any).componentRef;
    if (componentRef) {
      componentRef.destroy();
    }
  }
}
