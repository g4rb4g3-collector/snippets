import { Component } from '@angular/core';
import { trigger, transition, style, animate, group, query } from '@angular/animations';

@Component({
  selector: 'app-tab-navigation',
  template: `
    <div class="tabs">
      <button 
        *ngFor="let tab of tabs; let i = index"
        [class.active]="i === currentTab"
        (click)="selectTab(i)">
        {{ tab.title }}
      </button>
    </div>
    <div class="tab-content-wrapper" [@routeAnimation]="animationState">
      <div class="tab-content">
        {{ tabs[currentTab].content }}
      </div>
    </div>
  `,
  styleUrls: ['./tab-navigation.component.css'],
  animations: [
    trigger('routeAnimation', [
      transition('void => left', [
        style({ transform: 'translateX(100%)' }),
        animate('300ms ease', style({ transform: 'translateX(0)' }))
      ]),
      transition('void => right', [
        style({ transform: 'translateX(-100%)' }),
        animate('300ms ease', style({ transform: 'translateX(0)' }))
      ])
    ])
  ]
})
export class TabNavigationComponent {
  tabs = [
    { title: 'Tab 1', content: 'Content for Tab 1.' },
    { title: 'Tab 2', content: 'Content for Tab 2.' },
    { title: 'Tab 3', content: 'Content for Tab 3.' }
  ];
  currentTab = 0;
  animationState: string = 'left';

  selectTab(nextTab: number): void {
    if (nextTab === this.currentTab) return;
    this.animationState = nextTab > this.currentTab ? 'left' : 'right';
    this.currentTab = nextTab;
  }
}
